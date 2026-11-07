import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/classification_confidence.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/device_category.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovered_device_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/review_state.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_cubit.dart';

class MockIcmpStrategy extends IcmpDiscoveryStrategy {
  final Set<String> responsiveIps;
  MockIcmpStrategy(this.responsiveIps);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (responsiveIps.contains(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'ICMP echo reply in 2ms',
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'Request timed out',
    );
  }
}

void main() {
  group('Cross-Module Identity & Duplicate Detection Suite', () {
    late AppDatabase db;
    late DeviceRepositoryImpl deviceRepo;
    late InfrastructureRepositoryImpl infraRepo;
    late DiscoveryRepositoryImpl discoveryRepo;
    late NetworkRangeValidator rangeValidator;
    late DiscoveryCoordinator coordinator;
    late NetworkDiscoveryCubit cubit;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      deviceRepo = DeviceRepositoryImpl(db);
      infraRepo = InfrastructureRepositoryImpl(db);
      discoveryRepo = DiscoveryRepositoryImpl(db);
      rangeValidator = NetworkRangeValidator();

      final vendorLookup = MacVendorLookup();
      final classifier = DeviceClassificationEngine(vendorLookup);

      coordinator = DiscoveryCoordinator(
        discoveryRepo,
        deviceRepo,
        rangeValidator,
        classifier,
        vendorLookup,
        MockIcmpStrategy({'192.168.22.10', '192.168.27.50'}),
        ArpDiscoveryStrategy(vendorLookup),
        DnsHostnameStrategy(),
        TcpProbeDiscoveryStrategy(),
        OnvifDiscoveryStrategy(),
        MdnsSsdpDiscoveryStrategy(),
        infraRepo,
      );

      cubit = NetworkDiscoveryCubit(
        discoveryRepo,
        deviceRepo,
        coordinator,
        rangeValidator,
        infraRepo,
      );
    });

    tearDown(() async {
      await cubit.close();
      coordinator.dispose();
      await db.close();
    });

    test(
      '1. Existing UniFi AP appearing in discovery is recognized as alreadyKnown without double counting',
      () async {
        // Seed an authentic UniFi AP in infrastructure_devices
        final savedInfraRes = await infraRepo.saveInfrastructureDevice(
          UniFiDeviceEntity(
            id: 0,
            name: 'UniFi AP-AC-Pro-Hall',
            ip: '192.168.22.10',
            role: UniFiDeviceRole.accessPoint,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        expect(savedInfraRes.isSuccess, isTrue);
        final ap = savedInfraRes.dataOrNull!;

        // Simulate discovery scan discovering 192.168.22.10
        final scanRes = await coordinator.startScan(
          requestedRanges: ['192.168.22.8/30'],
          enabledStrategies: ['icmp'],
          maxConcurrency: 1,
          timeoutSeconds: 1,
        );
        expect(scanRes.isSuccess, isTrue);

        // Wait for scan completion
        await Future.delayed(const Duration(milliseconds: 300));

        final discoveredRes = await discoveryRepo.getDiscoveredDevices();
        expect(discoveredRes.isSuccess, isTrue);
        final discovered = discoveredRes.dataOrNull!;

        expect(discovered.isNotEmpty, isTrue);
        final dev = discovered.firstWhere((d) => d.ip == '192.168.22.10');
        // Must be identified as alreadyKnown, matching infrastructure!
        expect(dev.reviewState, equals(ReviewState.alreadyKnown));
        expect(dev.associatedDeviceId, equals(10000 + ap.id));
        expect(
          dev.predictedCategory,
          equals(DeviceCategory.wirelessAccessPoint),
        );

        // Inventory table remains completely empty (AP belongs strictly to infrastructure)
        final invRes = await deviceRepo.getDevices();
        expect(invRes.dataOrNull!.isEmpty, isTrue);
      },
    );

    test(
      '2. Discovered device matching an existing inventory device is flagged alreadyKnown',
      () async {
        // Seed an inventory device
        final addRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-SALES-01',
            type: DeviceType.pc,
            ip: '192.168.27.50',
            ownerName: 'Alice',
            department: 'Sales',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        expect(addRes.isSuccess, isTrue);
        final invDev = addRes.dataOrNull!;

        final scanRes = await coordinator.startScan(
          requestedRanges: ['192.168.27.48/30'],
          enabledStrategies: ['icmp'],
          maxConcurrency: 1,
          timeoutSeconds: 1,
        );
        expect(scanRes.isSuccess, isTrue);

        await Future.delayed(const Duration(milliseconds: 300));

        final discoveredRes = await discoveryRepo.getDiscoveredDevices();
        expect(discoveredRes.dataOrNull!.isNotEmpty, isTrue);
        final dev = discoveredRes.dataOrNull!.firstWhere(
          (d) => d.ip == '192.168.27.50',
        );
        expect(dev.reviewState, equals(ReviewState.alreadyKnown));
        expect(dev.associatedDeviceId, equals(invDev.id));
      },
    );

    test(
      '3. Cross-module duplicate prevention: infrastructure IP cannot be added or approved into devices table',
      () async {
        // Seed UniFi Gateway
        final savedInfraRes = await infraRepo.saveInfrastructureDevice(
          UniFiDeviceEntity(
            id: 0,
            name: 'UniFi Gateway Pro',
            ip: '192.168.27.1',
            role: UniFiDeviceRole.gateway,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        expect(savedInfraRes.isSuccess, isTrue);
        final gateway = savedInfraRes.dataOrNull!;

        // 1. Direct CRUD attempt to add the same IP into devices table must be rejected
        final dupDev = DeviceEntity(
          id: 0,
          name: 'Fake Gateway Duplicate',
          type: DeviceType.pc,
          ip: '192.168.27.1',
          ownerName: 'Hacker',
          department: 'IT',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final directAddRes = await deviceRepo.addDevice(dupDev);
        expect(directAddRes.isSuccess, isFalse);
        expect(directAddRes.failureOrNull, isA<ValidationFailure>());
        expect(
          directAddRes.failureOrNull?.message,
          contains('already assigned to infrastructure device'),
        );

        // 2. Discovered device on 192.168.27.1 approved via NetworkDiscoveryCubit
        final now = DateTime.now();
        final discovered = DiscoveredDeviceEntity(
          id: 1,
          scanId: 1,
          ip: '192.168.27.1',
          predictedCategory: DeviceCategory.wirelessAccessPoint,
          confidence: ClassificationConfidence.high,
          reviewState: ReviewState.pendingReview,
          firstSeen: now,
          lastSeen: now,
        );
        await discoveryRepo.saveDiscoveredDevice(discovered);

        final approved = await cubit.approveDevice(
          discoveredDevice: discovered,
          confirmedCategory: DeviceCategory.wirelessAccessPoint,
          deviceName: 'Approved UniFi Gateway',
          ownerName: 'Network Ops',
          department: 'Infrastructure',
        );
        expect(approved, isTrue);

        // Verification: Devices table must STILL be empty!
        final devices = await deviceRepo.getDevices();
        expect(devices.dataOrNull!.isEmpty, isTrue);

        // Discovered record is associated with the authoritative infrastructure device
        final updatedDiscovered = await discoveryRepo.getDiscoveredDevices();
        expect(
          updatedDiscovered.dataOrNull!.first.associatedDeviceId,
          equals(10000 + gateway.id),
        );
      },
    );

    test(
      '4. Retrying device approval is idempotent and does not create duplicate entries',
      () async {
        final now = DateTime.now();
        final discovered = DiscoveredDeviceEntity(
          id: 2,
          scanId: 1,
          ip: '192.168.27.60',
          predictedCategory: DeviceCategory.pc,
          confidence: ClassificationConfidence.high,
          reviewState: ReviewState.pendingReview,
          firstSeen: now,
          lastSeen: now,
        );
        await discoveryRepo.saveDiscoveredDevice(discovered);

        // First approval
        final res1 = await cubit.approveDevice(
          discoveredDevice: discovered,
          confirmedCategory: DeviceCategory.pc,
          deviceName: 'PC-RETRY-01',
          ownerName: 'Alice',
          department: 'Finance',
        );
        expect(res1, isTrue);

        // Second approval (Retry / Double-click)
        final res2 = await cubit.approveDevice(
          discoveredDevice: discovered,
          confirmedCategory: DeviceCategory.pc,
          deviceName: 'PC-RETRY-01',
          ownerName: 'Alice',
          department: 'Finance',
        );
        expect(res2, isTrue);

        // Devices table must contain EXACTLY ONE record
        final allDevices = await deviceRepo.getDevices();
        expect(allDevices.dataOrNull!.length, equals(1));
        expect(allDevices.dataOrNull!.first.ip, equals('192.168.27.60'));
        expect(allDevices.dataOrNull!.first.name, equals('PC-RETRY-01'));
      },
    );

    test(
      '5. Device changed or deleted while discovery is pending approves cleanly without orphaned references',
      () async {
        // Pre-existing device
        final addRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-TEMP',
            type: DeviceType.pc,
            ip: '192.168.27.70',
            ownerName: 'Old Owner',
            department: 'Old Dept',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final dev = addRes.dataOrNull!;

        // Delete device before discovery approval executes
        await deviceRepo.deleteDevice(dev.id);

        final now = DateTime.now();
        final discovered = DiscoveredDeviceEntity(
          id: 3,
          scanId: 1,
          ip: '192.168.27.70',
          predictedCategory: DeviceCategory.pc,
          confidence: ClassificationConfidence.high,
          reviewState: ReviewState.pendingReview,
          firstSeen: now,
          lastSeen: now,
        );
        await discoveryRepo.saveDiscoveredDevice(discovered);

        // Approve creates new device cleanly
        final approved = await cubit.approveDevice(
          discoveredDevice: discovered,
          confirmedCategory: DeviceCategory.pc,
          deviceName: 'PC-RE-CREATED',
          ownerName: 'New Owner',
          department: 'New Dept',
        );
        expect(approved, isTrue);

        final currentDevices = await deviceRepo.getDevices();
        expect(currentDevices.dataOrNull!.length, equals(1));
        expect(currentDevices.dataOrNull!.first.name, equals('PC-RE-CREATED'));
        expect(currentDevices.dataOrNull!.first.ownerName, equals('New Owner'));
      },
    );
  });
}
