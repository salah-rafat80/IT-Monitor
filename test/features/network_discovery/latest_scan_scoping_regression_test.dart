import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_import_commit_payload.dart';
import 'package:it_network_monitor/features/devices/domain/entities/inventory_import_preview.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/classification_confidence.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/device_category.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovered_device_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_evidence_item.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_scan_job.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/review_state.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_cubit.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_state.dart';

class _FakeDeviceRepository implements DeviceRepository {
  final List<DeviceEntity> _devices = [];
  @override
  Future<Result<List<DeviceEntity>>> getDevices({String? factoryId}) async =>
      Result.success(List.from(_devices));
  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async =>
      Result.failure(Exception('Not found') as dynamic);
  @override
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device) async {
    _devices.add(device);
    return Result.success(device);
  }
  @override
  Future<Result<DeviceEntity>> updateDevice(DeviceEntity device) async =>
      Result.success(device);
  @override
  Future<Result<DeviceEntity>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
    String? adminUsername,
  }) async => Result.success(_devices.first);
  @override
  Future<Result<void>> deleteDevice(int id) async => Result.success(null);
  @override
  Future<Result<void>> toggleDeviceMonitoring({
    required int deviceId,
    required bool isEnabled,
  }) async => Result.success(null);
  @override
  Future<Result<InventoryImportPreview>> parseAndValidateImport(
    List<int> bytes,
    String filename,
  ) async => Result.success(const InventoryImportPreview(
    validDevices: [],
    excludedDuplicateIps: [],
    invalidRecords: [],
    totalRowsProcessed: 0,
  ));
  @override
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices) async =>
      Result.success(validDevices.length);
  @override
  Future<Result<int>> commitImportPayload(DeviceImportCommitPayload payload) async =>
      Result.success(payload.inserts.length + payload.updates.length);
  @override
  Future<Result<int>> bootstrapApprovedInventory({bool force = false}) async =>
      Result.success(_devices.length);
  @override
  Future<Result<int>> reassignDevicesFactory({
    required List<int> deviceIds,
    required String targetFactoryId,
    String? adminUsername,
  }) async => Result.success(deviceIds.length);
  @override
  Future<Result<int>> deleteDevices(List<int> deviceIds) async =>
      Result.success(deviceIds.length);
  @override
  Future<Result<int>> bulkUpdateDevices({
    required List<int> deviceIds,
    DeviceType? type,
    String? department,
    String? officeLocation,
    String? vendor,
    bool? isMonitored,
    bool? isEnabled,
  }) async => Result.success(deviceIds.length);
}

void main() {
  late AppDatabase db;
  late DiscoveryRepositoryImpl discoveryRepo;
  late _FakeDeviceRepository deviceRepo;
  late NetworkRangeValidator validator;
  late DiscoveryCoordinator coordinator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    discoveryRepo = DiscoveryRepositoryImpl(db);
    deviceRepo = _FakeDeviceRepository();
    validator = NetworkRangeValidator();

    final vendorLookup = MacVendorLookup();
    coordinator = DiscoveryCoordinator(
      discoveryRepo,
      deviceRepo,
      validator,
      DeviceClassificationEngine(vendorLookup),
      vendorLookup,
      IcmpDiscoveryStrategy(),
      ArpDiscoveryStrategy(vendorLookup),
      DnsHostnameStrategy(),
      TcpProbeDiscoveryStrategy(),
      OnvifDiscoveryStrategy(),
      MdnsSsdpDiscoveryStrategy(),
    );
  });

  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  group('Fix Round 5: Latest Scan Scoping & Stale Device Elimination', () {
    test(
      'Seed DB with device from old scanId, load cubit with newer scan -> old device is NOT in state',
      () async {
        const factoryId = 'rnf';

        // 1. Create Old Scan (scanId = 1)
        final scan1Job = DiscoveryScanJob(
          id: 1,
          factoryId: factoryId,
          status: ScanJobStatus.completed,
          targetRanges: const ['192.168.1.0/24'],
          enabledStrategies: const ['icmp'],
          startedAt: DateTime.now().subtract(const Duration(days: 7)),
          completedAt: DateTime.now().subtract(const Duration(days: 7)),
        );
        final scan1Res = await discoveryRepo.createScanJob(scan1Job);
        expect(scan1Res.isSuccess, isTrue);
        final scanId1 = scan1Res.dataOrNull!;

        // 2. Save a device that only responded to Scan 1 (e.g. camera offline today)
        final oldCameraDevice = DiscoveredDeviceEntity(
          scanId: scanId1,
          factoryId: factoryId,
          ip: '192.168.1.150',
          mac: '00:11:22:33:44:55',
          hostname: 'STALE-CAMERA-01',
          predictedCategory: DeviceCategory.ipCamera,
          confidence: ClassificationConfidence.high,
          firstSeen: DateTime.now().subtract(const Duration(days: 7)),
          lastSeen: DateTime.now().subtract(const Duration(days: 7)),
          reviewState: ReviewState.pendingReview,
        );
        final saveDev1 = await discoveryRepo.saveDiscoveredDevice(oldCameraDevice);
        expect(saveDev1.isSuccess, isTrue);

        // 3. Create Newer Scan (scanId = 2)
        final scan2Job = DiscoveryScanJob(
          id: 2,
          factoryId: factoryId,
          status: ScanJobStatus.completed,
          targetRanges: const ['192.168.1.0/24'],
          enabledStrategies: const ['icmp'],
          startedAt: DateTime.now(),
          completedAt: DateTime.now(),
        );
        final scan2Res = await discoveryRepo.createScanJob(scan2Job);
        expect(scan2Res.isSuccess, isTrue);
        final scanId2 = scan2Res.dataOrNull!;

        // 4. Save a device that answered in Scan 2 (e.g. active printer)
        final activePrinterDevice = DiscoveredDeviceEntity(
          scanId: scanId2,
          factoryId: factoryId,
          ip: '192.168.1.200',
          mac: 'AA:BB:CC:DD:EE:FF',
          hostname: 'ACTIVE-PRINTER-01',
          predictedCategory: DeviceCategory.printer,
          confidence: ClassificationConfidence.high,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
          reviewState: ReviewState.pendingReview,
        );
        final saveDev2 = await discoveryRepo.saveDiscoveredDevice(activePrinterDevice);
        expect(saveDev2.isSuccess, isTrue);

        // 5. Initialize NetworkDiscoveryCubit for 'rnf'
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init(factoryId: factoryId);

        // 6. Assertions:
        expect(cubit.state, isA<NetworkDiscoveryLoaded>());
        final state = cubit.state as NetworkDiscoveryLoaded;

        // Latest scan must be scan 2
        expect(state.latestScan, isNotNull);
        expect(state.latestScan!.id, equals(scanId2));

        // The old device from scan 1 MUST NOT be present in state
        final hasOldDevice = state.discoveredDevices.any((d) => d.ip == '192.168.1.150');
        expect(hasOldDevice, isFalse, reason: 'Old device from previous scan must not appear');

        // Only the device that answered scan 2 must be present
        expect(state.discoveredDevices.length, equals(1));
        expect(state.discoveredDevices.first.ip, equals('192.168.1.200'));
        expect(state.discoveredDevices.first.hostname, equals('ACTIVE-PRINTER-01'));
        expect(state.discoveredDevices.first.scanId, equals(scanId2));

        await cubit.close();
      },
    );

    test(
      'Factory with no scans returns clean honest empty state without leaking rows',
      () async {
        // Seed database with a scan and device for 'rnf'
        final rnfJob = DiscoveryScanJob(
          id: 1,
          factoryId: 'rnf',
          status: ScanJobStatus.completed,
          targetRanges: const ['192.168.1.0/24'],
          enabledStrategies: const ['icmp'],
          startedAt: DateTime.now(),
          completedAt: DateTime.now(),
        );
        await discoveryRepo.createScanJob(rnfJob);
        await discoveryRepo.saveDiscoveredDevice(
          DiscoveredDeviceEntity(
            scanId: 1,
            factoryId: 'rnf',
            ip: '192.168.1.50',
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );

        // Load cubit for 'bnf' where no scans have ever been run
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init(factoryId: 'bnf');

        expect(cubit.state, isA<NetworkDiscoveryLoaded>());
        final state = cubit.state as NetworkDiscoveryLoaded;
        expect(state.latestScan, isNull);
        expect(state.discoveredDevices, isEmpty);
        expect(state.filteredDevices, isEmpty);

        await cubit.close();
      },
    );

    test(
      'When new scan starts, old devices disappear immediately and view follows new scan',
      () async {
        const factoryId = 'rnf';

        // 1. Initial completed scan with device A
        final scan1 = DiscoveryScanJob(
          id: 1,
          factoryId: factoryId,
          status: ScanJobStatus.completed,
          targetRanges: const ['192.168.1.0/24'],
          enabledStrategies: const ['icmp'],
          startedAt: DateTime.now().subtract(const Duration(hours: 1)),
          completedAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await discoveryRepo.createScanJob(scan1);
        await discoveryRepo.saveDiscoveredDevice(
          DiscoveredDeviceEntity(
            scanId: 1,
            factoryId: factoryId,
            ip: '192.168.1.10',
            hostname: 'DEVICE-OLD',
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );

        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init(factoryId: factoryId);

        var state = cubit.state as NetworkDiscoveryLoaded;
        expect(state.discoveredDevices.length, equals(1));
        expect(state.discoveredDevices.first.ip, equals('192.168.1.10'));

        // 2. Start a new scan (scanId = 2) in running state
        final scan2 = DiscoveryScanJob(
          id: 2,
          factoryId: factoryId,
          status: ScanJobStatus.running,
          targetRanges: const ['192.168.1.0/24'],
          enabledStrategies: const ['icmp'],
          startedAt: DateTime.now(),
        );
        await discoveryRepo.createScanJob(scan2);

        // Allow watchLatestScanJob / cubit to receive the new scan update
        await pumpEventQueue();

        state = cubit.state as NetworkDiscoveryLoaded;
        // Old device must disappear immediately
        expect(state.discoveredDevices, isEmpty, reason: 'Previous scan devices must disappear when new scan starts');

        // 3. New responder is found during running scan
        await discoveryRepo.saveDiscoveredDevice(
          DiscoveredDeviceEntity(
            scanId: 2,
            factoryId: factoryId,
            ip: '192.168.1.20',
            hostname: 'DEVICE-NEW',
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );

        await pumpEventQueue();

        state = cubit.state as NetworkDiscoveryLoaded;
        expect(state.discoveredDevices.length, equals(1));
        expect(state.discoveredDevices.first.ip, equals('192.168.1.20'));
        expect(state.discoveredDevices.first.scanId, equals(2));

        await cubit.close();
      },
    );

    test(
      'deleteDiscoveredDevicesForOlderScans cleans up DB rows and attached evidence for old scans',
      () async {
        const factoryId = 'rnf';

        // Scan 1 with device & evidence
        final dev1Res = await discoveryRepo.saveDiscoveredDevice(
          DiscoveredDeviceEntity(
            scanId: 1,
            factoryId: factoryId,
            ip: '192.168.1.10',
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );
        final dev1Id = dev1Res.dataOrNull!;
        await discoveryRepo.saveEvidence(
          dev1Id,
          DiscoveryEvidenceItem(
            strategyName: 'icmp',
            probeTarget: '192.168.1.10',
            isSuccess: true,
            details: 'Responded',
            timestamp: DateTime.now(),
          ),
        );

        // Scan 2 with device & evidence
        final dev2Res = await discoveryRepo.saveDiscoveredDevice(
          DiscoveredDeviceEntity(
            scanId: 2,
            factoryId: factoryId,
            ip: '192.168.1.20',
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );
        final dev2Id = dev2Res.dataOrNull!;
        await discoveryRepo.saveEvidence(
          dev2Id,
          DiscoveryEvidenceItem(
            strategyName: 'icmp',
            probeTarget: '192.168.1.20',
            isSuccess: true,
            details: 'Responded',
            timestamp: DateTime.now(),
          ),
        );

        // Perform cleanup keeping only scan 2
        final cleanRes = await discoveryRepo.deleteDiscoveredDevicesForOlderScans(
          factoryId: factoryId,
          keepScanId: 2,
        );
        expect(cleanRes.isSuccess, isTrue);

        // Assert scan 1 device is purged from DB
        final dev1Lookup = await discoveryRepo.getEvidenceForDevice(dev1Id);
        expect(dev1Lookup.dataOrNull, isEmpty);

        // Assert scan 2 device and evidence remain intact
        final dev2Lookup = await discoveryRepo.getEvidenceForDevice(dev2Id);
        expect(dev2Lookup.dataOrNull?.length, equals(1));
      },
    );
  });
}
