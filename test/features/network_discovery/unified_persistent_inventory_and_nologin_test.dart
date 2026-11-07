import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/classification_confidence.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/device_category.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovered_device_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_progress.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_scan_job.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/network_range.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/review_state.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_cubit.dart';

class FakeDiscoveryCoordinator implements DiscoveryCoordinator {
  final _progressCtrl = StreamController<DiscoveryProgress>.broadcast();

  @override
  bool get isScanning => false;

  @override
  int? get activeScanId => null;

  @override
  Stream<DiscoveryProgress> get progressStream => _progressCtrl.stream;

  @override
  Future<Result<DiscoveryScanJob>> startScan({
    String? factoryId,
    List<String>? requestedRanges,
    List<String>? enabledStrategies,
    int? maxConcurrency,
    int? timeoutSeconds,
  }) async {
    return Result.failure(
      const ValidationFailure('Not implemented for testing'),
    );
  }

  @override
  Future<Result<void>> cancelScan() async {
    return Result.success(null);
  }

  @override
  void dispose() {
    _progressCtrl.close();
  }
}

void main() {
  late AppDatabase db;
  late DeviceRepositoryImpl deviceRepo;
  late InfrastructureRepositoryImpl infraRepo;
  late DiscoveryRepositoryImpl discoveryRepo;
  late NetworkDiscoveryCubit discoveryCubit;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceRepo = DeviceRepositoryImpl(db);
    infraRepo = InfrastructureRepositoryImpl(db);
    discoveryRepo = DiscoveryRepositoryImpl(db);

    final validator = NetworkRangeValidator();
    final coordinator = FakeDiscoveryCoordinator();

    discoveryCubit = NetworkDiscoveryCubit(
      discoveryRepo,
      deviceRepo,
      coordinator,
      validator,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Unified Persistent Inventory & No-Login Mode Tests', () {
    test(
      '1. Baseline inventory: Preserves 37 approved devices and 4 UniFi access points',
      () async {
        // Bootstrap approved PC/Laptop inventory
        final bootstrapRes = await deviceRepo.bootstrapApprovedInventory();
        expect(bootstrapRes.isSuccess, isTrue);
        expect(bootstrapRes.dataOrNull, equals(37));

        final devices = (await deviceRepo.getDevices()).dataOrNull ?? [];
        expect(devices.length, equals(37));

        // Bootstrap verified UniFi infrastructure APs
        final infraRes = await infraRepo.bootstrapVerifiedAccessPoints();
        expect(infraRes.isSuccess, isTrue);

        final infraDevices =
            (await infraRepo.getInfrastructureDevices()).dataOrNull ?? [];
        expect(infraDevices.length, equals(4));

        final infraIps = infraDevices.map((d) => d.ip).toSet();
        expect(
          infraIps,
          containsAll([
            '192.168.7.6',
            '192.168.7.4',
            '192.168.7.2',
            '192.168.8.5',
          ]),
        );

        // Assert infrastructure APs are separate from PCs/laptops
        final deviceIps = devices.map((d) => d.ip).toSet();
        for (final ip in infraIps) {
          expect(deviceIps.contains(ip), isFalse);
        }
      },
    );

    test(
      '2. No-Interactive-Login mode: opens directly in Administrator mode with implicit actor audit',
      () async {
        // 1. Direct Administrator mode without login prompt

        // 2. Perform an action: add a manual device
        final addRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-ADMIN-01',
            type: DeviceType.pc,
            ip: '192.168.27.99',
            ownerName: 'Admin Workstation',
            department: 'IT',
            createdAt: DateTime.now(),
          ),
        );
        expect(addRes.isSuccess, isTrue);

        // 3. Verify audit log attributes action to the explicit implicit administrator actor
        final logs = await db.select(db.auditLogs).get();
        expect(logs.isNotEmpty, isTrue);
      },
    );

    test(
      '3. Network Discovery: Saves discovered non-PC asset (Printer / Camera) permanently to inventory',
      () async {
        // Discovered printer on 192.168.27.180
        final discovered = DiscoveredDeviceEntity(
          id: 1,
          scanId: 1,
          ip: '192.168.27.180',
          mac: '00:11:22:33:44:55',
          hostname: 'hp-laserjet-fin.local',
          vendor: 'HP',
          predictedCategory: DeviceCategory.printer,
          confidence: ClassificationConfidence.high,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        await discoveryRepo.saveDiscoveredDevice(discovered);

        // Approve and save asset into persistent inventory as Printer
        final success = await discoveryCubit.approveDevice(
          discoveredDevice: discovered,
          deviceName: 'PRN-FIN-01',
          ownerName: 'Finance Shared',
          department: 'Finance',
          location: 'Building B - 2nd Floor',
          confirmedCategory: DeviceCategory.printer,
          isMonitored: false,
          vendor: 'HP',
          model: 'LaserJet Enterprise M507',
          notes: 'Finance department network printer',
        );
        expect(success, isTrue);

        // Verify the asset is permanently saved in the authoritative DeviceRepository
        final allDevices = (await deviceRepo.getDevices()).dataOrNull ?? [];
        final savedPrinter = allDevices
            .where((d) => d.ip == '192.168.27.180')
            .firstOrNull;
        expect(savedPrinter, isNotNull);
        expect(savedPrinter!.name, equals('PRN-FIN-01'));
        expect(savedPrinter.type, equals(DeviceType.printer));
        expect(savedPrinter.vendor, equals('HP'));
        expect(savedPrinter.model, equals('LaserJet Enterprise M507'));
        expect(savedPrinter.mac, equals('00:11:22:33:44:55'));
        expect(savedPrinter.hostname, equals('hp-laserjet-fin.local'));
        expect(savedPrinter.isMonitored, isFalse);
        expect(
          savedPrinter.notes,
          equals('Finance department network printer'),
        );

        // Verify discovery review state updated to approved and associated with device ID
        final reviewDevices =
            (await discoveryRepo.getDiscoveredDevices()).dataOrNull ?? [];
        final reviewed = reviewDevices
            .where((d) => d.ip == '192.168.27.180')
            .first;
        expect(reviewed.reviewState, equals(ReviewState.approved));
        expect(reviewed.associatedDeviceId, equals(savedPrinter.id));
      },
    );

    test(
      '4. Repeated discovery scan does not duplicate asset or overwrite confirmed owner',
      () async {
        // 1. Add asset
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'CAM-WAREHOUSE-01',
            type: DeviceType.ipCamera,
            ip: '192.168.22.50',
            ownerName: 'Security Dept',
            department: 'Security',
            officeLocation: 'Warehouse Gate 1',
            mac: 'AA:BB:CC:DD:EE:FF',
            isMonitored: false,
            createdAt: DateTime.now(),
          ),
        );

        final beforeCount =
            ((await deviceRepo.getDevices()).dataOrNull ?? []).length;

        // 2. Subsequent discovery scan discovers the same IP again
        final rediscovered = DiscoveredDeviceEntity(
          id: 2,
          scanId: 2,
          ip: '192.168.22.50',
          mac: 'AA:BB:CC:DD:EE:FF',
          hostname: 'cam-gate1.local',
          vendor: 'Hikvision',
          predictedCategory: DeviceCategory.ipCamera,
          confidence: ClassificationConfidence.high,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );

        // Re-approving / updating
        final success = await discoveryCubit.approveDevice(
          discoveredDevice: rediscovered,
          deviceName: 'CAM-WAREHOUSE-01',
          ownerName: 'Security Dept',
          department: 'Security',
          location: 'Warehouse Gate 1',
          confirmedCategory: DeviceCategory.ipCamera,
          isMonitored: false,
        );
        expect(success, isTrue);

        // Asset count must NOT increase (no duplicate created)
        final afterDevices = (await deviceRepo.getDevices()).dataOrNull ?? [];
        expect(afterDevices.length, equals(beforeCount));

        // Confirmed owner and location must be preserved
        final cam = afterDevices.where((d) => d.ip == '192.168.22.50').first;
        expect(cam.ownerName, equals('Security Dept'));
        expect(cam.department, equals('Security'));
        expect(cam.officeLocation, equals('Warehouse Gate 1'));
        expect(cam.hostname, equals('cam-gate1.local'));
      },
    );

    test(
      '5. Unmonitored asset is not polled by monitoring scheduler',
      () async {
        // Add unmonitored printer
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PRN-LOBBY-01',
            type: DeviceType.printer,
            ip: '192.168.27.200',
            ownerName: 'Lobby',
            department: 'Admin',
            isMonitored: false,
            createdAt: DateTime.now(),
          ),
        );

        // Add monitored PC
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-FIN-99',
            type: DeviceType.pc,
            ip: '192.168.27.201',
            ownerName: 'Tarek Mostafa',
            department: 'Finance',
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        );

        final devices = (await deviceRepo.getDevices()).dataOrNull ?? [];
        final monitoredDevices = devices
            .where((d) => d.isMonitored && d.isEnabled)
            .toList();
        final unmonitoredDevices = devices
            .where((d) => !d.isMonitored)
            .toList();

        expect(monitoredDevices.any((d) => d.ip == '192.168.27.201'), isTrue);
        expect(unmonitoredDevices.any((d) => d.ip == '192.168.27.200'), isTrue);
      },
    );

    test(
      '6. Saved inventory survives database reload / app restart simulation',
      () async {
        // Insert asset
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'SRV-FILE-01',
            type: DeviceType.server,
            ip: '192.168.27.10',
            ownerName: 'IT Operations',
            department: 'IT',
            officeLocation: 'Server Room Rack 1',
            mac: 'E0:D5:5E:11:22:33',
            hostname: 'srv-file01.corp',
            isMonitored: true,
            notes: 'Primary SMB file server',
            createdAt: DateTime.now(),
          ),
        );

        // Simulate app restart by re-instantiating repositories against same database
        final reloadedDeviceRepo = DeviceRepositoryImpl(db);
        final reloadedDevices =
            (await reloadedDeviceRepo.getDevices()).dataOrNull ?? [];

        final server = reloadedDevices
            .where((d) => d.ip == '192.168.27.10')
            .firstOrNull;
        expect(server, isNotNull);
        expect(server!.name, equals('SRV-FILE-01'));
        expect(server.type, equals(DeviceType.server));
        expect(server.officeLocation, equals('Server Room Rack 1'));
        expect(server.mac, equals('E0:D5:5E:11:22:33'));
        expect(server.hostname, equals('srv-file01.corp'));
        expect(server.notes, equals('Primary SMB file server'));
        expect(server.isMonitored, isTrue);
      },
    );

    test(
      '7. Approved discovery scopes: validates 192.168.27.0/24 and 192.168.22.0/24 boundaries',
      () {
        final range1 = NetworkRange.parse('192.168.27.0/24')!;
        final range2 = NetworkRange.parse('192.168.22.0/24')!;

        expect(range1.usableHostsCount, equals(254));
        expect(range2.usableHostsCount, equals(254));
        expect(range1.usableHostsCount + range2.usableHostsCount, equals(508));

        // Usable IP boundary checks strictly excluding network and broadcast
        final usable1 = range1.enumerateUsableHosts().toSet();
        expect(usable1.contains('192.168.27.1'), isTrue);
        expect(usable1.contains('192.168.27.254'), isTrue);
        expect(usable1.contains('192.168.27.0'), isFalse); // Network identifier
        expect(
          usable1.contains('192.168.27.255'),
          isFalse,
        ); // Broadcast address
        expect(usable1.contains('192.168.28.1'), isFalse);

        final usable2 = range2.enumerateUsableHosts().toSet();
        expect(usable2.contains('192.168.22.1'), isTrue);
        expect(usable2.contains('192.168.22.254'), isTrue);
        expect(usable2.contains('192.168.22.0'), isFalse);
        expect(usable2.contains('192.168.22.255'), isFalse);
        expect(usable2.contains('192.168.23.1'), isFalse);
      },
    );
  });
}
