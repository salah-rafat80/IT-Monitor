import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/inventory_import_preview.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/classification_confidence.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/device_category.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovered_device_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_config_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_evidence_item.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_scan_job.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/network_range.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/review_state.dart';
import 'package:it_network_monitor/features/network_discovery/domain/repositories/discovery_repository.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_cubit.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_state.dart';

// ── In-Memory Fake Device Repository ──────────────────────────────────────────
class FakeDeviceRepository implements DeviceRepository {
  final List<DeviceEntity> _devices = [];

  FakeDeviceRepository([List<DeviceEntity>? initialDevices]) {
    if (initialDevices != null) _devices.addAll(initialDevices);
  }

  @override
  Future<Result<List<DeviceEntity>>> getDevices({String? factoryId}) async {
    if (factoryId != null) {
      return Result.success(
        _devices.where((d) => d.factoryId == factoryId).toList(),
      );
    }
    return Result.success(List.from(_devices));
  }

  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async {
    final dev = _devices.where((d) => d.id == id).firstOrNull;
    if (dev != null) return Result.success(dev);
    return Result.failure(Exception('Not found') as dynamic);
  }

  @override
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device) async {
    final newId = _devices.length + 1;
    final saved = device.copyWith(id: newId);
    _devices.add(saved);
    return Result.success(saved);
  }

  @override
  Future<Result<DeviceEntity>> updateDevice(DeviceEntity device) async {
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx != -1) _devices[idx] = device;
    return Result.success(device);
  }

  @override
  Future<Result<DeviceEntity>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
    String? adminUsername,
  }) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      final updated = _devices[idx].copyWith(ownerName: ownerName);
      _devices[idx] = updated;
      return Result.success(updated);
    }
    return Result.failure(Exception('Not found') as dynamic);
  }

  @override
  Future<Result<void>> deleteDevice(int id) async {
    _devices.removeWhere((d) => d.id == id);
    return Result.success(null);
  }

  @override
  Future<Result<void>> toggleDeviceMonitoring({
    required int deviceId,
    required bool isEnabled,
  }) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      _devices[idx] = _devices[idx].copyWith(isMonitored: isEnabled);
    }
    return Result.success(null);
  }

  @override
  Future<Result<InventoryImportPreview>> parseAndValidateImport(
    List<int> bytes,
    String filename,
  ) async => Result.success(
    const InventoryImportPreview(
      validDevices: [],
      excludedDuplicateIps: [],
      invalidRecords: [],
      totalRowsProcessed: 0,
    ),
  );

  @override
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices) async {
    for (final d in validDevices) {
      await addDevice(d);
    }
    return Result.success(validDevices.length);
  }

  @override
  Future<Result<int>> bootstrapApprovedInventory({bool force = false}) async =>
      Result.success(_devices.length);
}

// ── Mock Strategies ───────────────────────────────────────────────────────────
class TestIcmpStrategy extends IcmpDiscoveryStrategy {
  final Set<String> liveIps;
  TestIcmpStrategy(this.liveIps);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (liveIps.contains(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'ICMP echo reply in 3ms',
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'Host unreachable',
    );
  }
}

class TestArpStrategy extends ArpDiscoveryStrategy {
  final Map<String, String> ipToMac;
  TestArpStrategy(this.ipToMac, MacVendorLookup lookup) : super(lookup);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (ipToMac.containsKey(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'Dynamic ARP entry: ${ipToMac[targetIp]}',
        mac: ipToMac[targetIp],
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'No ARP entry',
    );
  }
}

class TestDnsStrategy extends DnsHostnameStrategy {
  final Map<String, String> ipToHost;
  TestDnsStrategy(this.ipToHost);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (ipToHost.containsKey(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: 'DNS PTR: ${ipToHost[targetIp]}',
        hostname: ipToHost[targetIp],
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'No DNS record',
    );
  }
}

class TestTcpStrategy extends TcpProbeDiscoveryStrategy {
  TestTcpStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'Closed',
      );
}

class TestOnvifStrategy extends OnvifDiscoveryStrategy {
  TestOnvifStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'No ONVIF',
      );
}

class TestMdnsStrategy extends MdnsSsdpDiscoveryStrategy {
  TestMdnsStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'No mDNS',
      );
}

// ── Failing Repository for Error Handling Tests ───────────────────────────────
class FailingSaveDiscoveryRepository implements DiscoveryRepository {
  final DiscoveryRepository _inner;
  bool shouldFail = true;

  FailingSaveDiscoveryRepository(this._inner);

  @override
  Future<Result<DiscoveryConfigEntity>> getConfig() => _inner.getConfig();

  @override
  Future<Result<void>> saveConfig(DiscoveryConfigEntity config) async {
    if (shouldFail) {
      return Result.failure(
        const NetworkFailure('Simulated service API persistence rejection'),
      );
    }
    return _inner.saveConfig(config);
  }

  @override
  Future<Result<List<NetworkRange>>> getRanges({String? factoryId}) =>
      _inner.getRanges(factoryId: factoryId);

  @override
  Future<Result<void>> addRange(NetworkRange range) async {
    if (shouldFail) {
      return Result.failure(
        const NetworkFailure('Simulated service API persistence rejection'),
      );
    }
    return _inner.addRange(range);
  }

  @override
  Future<Result<void>> updateRange(NetworkRange range) async {
    if (shouldFail) {
      return Result.failure(
        const NetworkFailure('Simulated service API persistence rejection'),
      );
    }
    return _inner.updateRange(range);
  }

  @override
  Future<Result<void>> deleteRange(String rangeId) async {
    if (shouldFail) {
      return Result.failure(
        const NetworkFailure('Simulated service API persistence rejection'),
      );
    }
    return _inner.deleteRange(rangeId);
  }

  @override
  Stream<List<NetworkRange>> watchRanges({String? factoryId}) =>
      _inner.watchRanges(factoryId: factoryId);

  @override
  Future<Result<int>> createScanJob(DiscoveryScanJob job) =>
      _inner.createScanJob(job);

  @override
  Future<Result<void>> updateScanJob(DiscoveryScanJob job) =>
      _inner.updateScanJob(job);

  @override
  Future<Result<DiscoveryScanJob>> getScanJob(int scanId) =>
      _inner.getScanJob(scanId);

  @override
  Future<Result<DiscoveryScanJob?>> getLatestScanJob({String? factoryId}) =>
      _inner.getLatestScanJob(factoryId: factoryId);

  @override
  Future<Result<List<DiscoveryScanJob>>> getAllScanJobs({String? factoryId}) =>
      _inner.getAllScanJobs(factoryId: factoryId);

  @override
  Future<Result<int>> saveDiscoveredDevice(DiscoveredDeviceEntity device) =>
      _inner.saveDiscoveredDevice(device);

  @override
  Future<Result<List<DiscoveredDeviceEntity>>> getDiscoveredDevices({
    String? factoryId,
    int? scanId,
  }) => _inner.getDiscoveredDevices(factoryId: factoryId, scanId: scanId);

  @override
  Future<Result<DiscoveredDeviceEntity?>> getDiscoveredDeviceByIp(
    String ip, {
    String? factoryId,
  }) => _inner.getDiscoveredDeviceByIp(ip, factoryId: factoryId);

  @override
  Future<Result<void>> updateDeviceReview({
    required int deviceId,
    required ReviewState state,
    DeviceCategory? confirmedCategory,
    int? reviewerId,
  }) => _inner.updateDeviceReview(
    deviceId: deviceId,
    state: state,
    confirmedCategory: confirmedCategory,
    reviewerId: reviewerId,
  );

  @override
  Future<Result<void>> saveEvidence(int deviceId, DiscoveryEvidenceItem item) =>
      _inner.saveEvidence(deviceId, item);

  @override
  Future<Result<List<DiscoveryEvidenceItem>>> getEvidenceForDevice(
    int deviceId,
  ) => _inner.getEvidenceForDevice(deviceId);

  @override
  Stream<DiscoveryScanJob?> watchLatestScanJob({String? factoryId}) =>
      _inner.watchLatestScanJob(factoryId: factoryId);

  @override
  Stream<List<DiscoveredDeviceEntity>> watchDiscoveredDevices({
    String? factoryId,
    int? scanId,
  }) => _inner.watchDiscoveredDevices(factoryId: factoryId, scanId: scanId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DiscoveryRepositoryImpl discoveryRepo;
  late FakeDeviceRepository deviceRepo;
  late NetworkRangeValidator validator;
  late DeviceClassificationEngine classifier;
  late MacVendorLookup vendorLookup;
  late DiscoveryCoordinator coordinator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    discoveryRepo = DiscoveryRepositoryImpl(db);
    deviceRepo = FakeDeviceRepository();
    validator = NetworkRangeValidator();
    vendorLookup = MacVendorLookup();
    classifier = DeviceClassificationEngine(vendorLookup);

    coordinator = DiscoveryCoordinator(
      discoveryRepo,
      deviceRepo,
      validator,
      classifier,
      vendorLookup,
      TestIcmpStrategy({'10.10.20.10'}),
      TestArpStrategy({'10.10.20.10': '00:11:22:33:44:55'}, vendorLookup),
      TestDnsStrategy({'10.10.20.10': 'server-01.lan'}),
      TestTcpStrategy(),
      TestOnvifStrategy(),
      TestMdnsStrategy(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Dynamic Network Range Management & Application-Wide Integration', () {
    // ── Scenario 1 ────────────────────────────────────────────────────────────
    test(
      '1. Fresh installation has no hidden dependency on previous hardcoded subnets',
      () async {
        final configRes = await discoveryRepo.getConfig();
        expect(configRes.isSuccess, isTrue);
        final config = configRes.dataOrNull!;

        // Verify no hardcoded ranges exist by default
        expect(config.networkRanges, isEmpty);
        expect(config.authorizedRanges, isEmpty);
        expect(config.allConfiguredRanges, isEmpty);

        // Starting discovery without ranges produces explicit validation failure
        final scanRes = await coordinator.startScan();
        expect(scanRes.isFailure, isTrue);
        expect(
          scanRes.failureOrNull?.message,
          contains('No valid authorized CIDR ranges'),
        );
      },
    );

    // ── Scenario 2 & 3 ────────────────────────────────────────────────────────
    test(
      '2 & 3. Admin adds 10.10.20.0/24: persisted successfully and appears in range list',
      () async {
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init();

        expect(cubit.state, isA<NetworkDiscoveryLoaded>());
        final initialLoaded = cubit.state as NetworkDiscoveryLoaded;
        expect(initialLoaded.rangesWithStatus, isEmpty);

        // Administrator adds 10.10.20.0/24 with descriptive name
        final addRes = await cubit.addNetworkRange(
          cidr: '10.10.20.0/24',
          name: 'HQ Server VLAN',
          isEnabled: true,
        );
        expect(addRes.isSuccess, isTrue);

        final stateAfterAdd = cubit.state as NetworkDiscoveryLoaded;
        expect(stateAfterAdd.config.networkRanges.length, equals(1));

        final range = stateAfterAdd.config.networkRanges.first;
        expect(range.cidr, equals('10.10.20.0/24'));
        expect(range.name, equals('HQ Server VLAN'));
        expect(range.isEnabled, isTrue);
        expect(range.usableHostsCount, equals(254));
        expect(range.baseIp, equals('10.10.20.0'));

        // Verify persistent repository state directly
        final repoRangesRes = await discoveryRepo.getRanges();
        expect(repoRangesRes.isSuccess, isTrue);
        expect(repoRangesRes.dataOrNull!.first.cidr, equals('10.10.20.0/24'));
        expect(repoRangesRes.dataOrNull!.first.name, equals('HQ Server VLAN'));

        await cubit.close();
      },
    );

    // ── Scenario 4 ────────────────────────────────────────────────────────────
    test(
      '4. Coordinator reads range from authoritative config and generates expected targets',
      () async {
        // Add range directly to authoritative repository
        final newRange = NetworkRange.parse(
          '10.10.20.0/24',
          name: 'Branch Office',
        )!;
        await discoveryRepo.addRange(newRange);

        // Verify coordinator picks up 10.10.20.0/24 automatically from repo config
        final scanRes = await coordinator.startScan();
        expect(scanRes.isSuccess, isTrue);
        final job = scanRes.dataOrNull!;
        expect(job.targetRanges, contains('10.10.20.0/24'));
        expect(job.targetsEnumerated, equals(254));
      },
    );

    // ── Scenario 5 ────────────────────────────────────────────────────────────
    test(
      '5. Added range survives application and service restart simulation',
      () async {
        // Step A: Save range to Drift database
        final range = NetworkRange.parse('172.16.50.0/24', name: 'DMZ Subnet')!;
        await discoveryRepo.addRange(range);

        // Step B: Simulate complete application shutdown and restart by re-instantiating repo from same DB
        final restartedRepo = DiscoveryRepositoryImpl(db);
        final reloadedConfigRes = await restartedRepo.getConfig();
        expect(reloadedConfigRes.isSuccess, isTrue);

        final reloadedConfig = reloadedConfigRes.dataOrNull!;
        expect(reloadedConfig.networkRanges.length, equals(1));
        expect(
          reloadedConfig.networkRanges.first.cidr,
          equals('172.16.50.0/24'),
        );
        expect(reloadedConfig.networkRanges.first.name, equals('DMZ Subnet'));
        expect(reloadedConfig.authorizedRanges, contains('172.16.50.0/24'));
      },
    );

    // ── Scenario 6 ────────────────────────────────────────────────────────────
    test(
      '6. Shared authoritative repository presents identical configuration to multiple consumers',
      () async {
        final client1 = DiscoveryRepositoryImpl(db);
        final client2 = DiscoveryRepositoryImpl(db);

        // Client 1 adds a range
        await client1.addRange(
          NetworkRange.parse('10.0.100.0/24', name: 'Lab Net')!,
        );

        // Client 2 reads config from shared database
        final client2Config = await client2.getConfig();
        expect(client2Config.isSuccess, isTrue);
        expect(
          client2Config.dataOrNull!.authorizedRanges,
          contains('10.0.100.0/24'),
        );
        expect(
          client2Config.dataOrNull!.networkRanges.first.name,
          equals('Lab Net'),
        );
      },
    );

    // ── Scenario 7 ────────────────────────────────────────────────────────────
    test(
      '7. Targeted scan uses newly configured range without source-code modifications',
      () async {
        final range = NetworkRange.parse('10.200.1.0/24')!;
        await discoveryRepo.addRange(range);

        // Launch targeted scan explicitly specifying the new range
        final scanRes = await coordinator.startScan(
          requestedRanges: ['10.200.1.0/24'],
        );
        expect(scanRes.isSuccess, isTrue);
        expect(scanRes.dataOrNull!.targetRanges, equals(['10.200.1.0/24']));
        expect(scanRes.dataOrNull!.targetsEnumerated, equals(254));
      },
    );

    // ── Scenario 8 ────────────────────────────────────────────────────────────
    test(
      '8. Enabling and disabling ranges dynamically adjusts targets for subsequent scans',
      () async {
        final range1 = NetworkRange.parse(
          '10.1.1.0/24',
          name: 'Scope 1',
          isEnabled: true,
        )!;
        final range2 = NetworkRange.parse(
          '10.1.2.0/24',
          name: 'Scope 2',
          isEnabled: true,
        )!;
        await discoveryRepo.addRange(range1);
        await discoveryRepo.addRange(range2);

        // Both enabled: 254 + 254 = 508 targets
        var scanRes = await coordinator.startScan();
        expect(scanRes.isSuccess, isTrue);
        // Complete/cancel first scan
        await coordinator.cancelScan();

        // Disable range2
        final updatedRange2 = range2.copyWith(isEnabled: false);
        await discoveryRepo.updateRange(updatedRange2);

        // Now only range1 is in authorizedRanges (254 targets)
        scanRes = await coordinator.startScan();
        expect(scanRes.isSuccess, isTrue);
        expect(scanRes.dataOrNull!.targetsEnumerated, equals(254));
        expect(scanRes.dataOrNull!.targetRanges, equals(['10.1.1.0/24']));
      },
    );

    // ── Scenario 9 ────────────────────────────────────────────────────────────
    test(
      '9. Invalid or excessive ranges produce clear validation errors and do not start scan',
      () async {
        // 9.1 Invalid format
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init();

        final invalidRes = await cubit.addNetworkRange(cidr: 'not-a-cidr');
        expect(invalidRes.isFailure, isTrue);
        expect(invalidRes.failureOrNull, isA<ValidationFailure>());
        expect(
          (cubit.state as NetworkDiscoveryLoaded).errorMessage,
          contains('Invalid CIDR format'),
        );

        // 9.2 Prefix too wide (/12 exceeds safe /16 bound)
        final tooWideRes = await cubit.addNetworkRange(cidr: '10.0.0.0/12');
        expect(tooWideRes.isFailure, isTrue);

        // 9.3 Coordinator rejects invalid range request without starting scan
        final scanRes = await coordinator.startScan(
          requestedRanges: ['invalid-ip/99'],
        );
        expect(scanRes.isFailure, isTrue);
        expect(
          scanRes.failureOrNull?.message,
          contains('No valid authorized CIDR ranges'),
        );

        await cubit.close();
      },
    );

    // ── Scenario 10 ───────────────────────────────────────────────────────────
    test(
      '10. Overlapping ranges do not produce duplicate scan targets',
      () async {
        // 10.0.0.0/24 and 10.0.0.0/25 completely overlap on 10.0.0.1..126
        final rangeA = NetworkRange.parse('10.0.0.0/24')!;
        final rangeB = NetworkRange.parse('10.0.0.0/25')!;
        await discoveryRepo.addRange(rangeA);
        await discoveryRepo.addRange(rangeB);

        final scanRes = await coordinator.startScan();
        expect(scanRes.isSuccess, isTrue);

        // Total targets should be deduplicated to exactly 254, NOT 254 + 126 = 380!
        expect(scanRes.dataOrNull!.targetsEnumerated, equals(254));
      },
    );

    // ── Scenario 11 ───────────────────────────────────────────────────────────
    test(
      '11. Persistence failure does not display false success and preserves state',
      () async {
        final failingRepo = FailingSaveDiscoveryRepository(discoveryRepo);
        final cubit = NetworkDiscoveryCubit(
          failingRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init();

        // Attempt to add range when persistence fails
        final addRes = await cubit.addNetworkRange(cidr: '10.50.0.0/24');
        expect(addRes.isFailure, isTrue);

        // State must not claim false success
        final state = cubit.state as NetworkDiscoveryLoaded;
        expect(
          state.config.networkRanges.any((r) => r.cidr == '10.50.0.0/24'),
          isFalse,
        );
        expect(
          state.errorMessage,
          contains('Simulated service API persistence rejection'),
        );

        await cubit.close();
      },
    );

    // ── Scenario 12 ───────────────────────────────────────────────────────────
    test(
      '12. Removing a range does not delete device inventory or historical records',
      () async {
        // Step A: Add range and save a discovered device under that range
        final range = NetworkRange.parse('10.10.20.0/24')!;
        await discoveryRepo.addRange(range);

        final device = DiscoveredDeviceEntity(
          scanId: 1,
          ip: '10.10.20.15',
          hostname: 'finance-pc',
          predictedCategory: DeviceCategory.pc,
          confidence: ClassificationConfidence.high,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        await discoveryRepo.saveDiscoveredDevice(device);

        // Step B: Remove the range
        final delRes = await discoveryRepo.deleteRange(range.id);
        expect(delRes.isSuccess, isTrue);

        // Verify range is removed from active configuration
        final configRes = await discoveryRepo.getConfig();
        expect(configRes.dataOrNull!.networkRanges, isEmpty);

        // Step C: Verify existing device is preserved intact
        final deviceCheck = await discoveryRepo.getDiscoveredDeviceByIp(
          '10.10.20.15',
        );
        expect(deviceCheck.isSuccess, isTrue);
        expect(deviceCheck.dataOrNull?.hostname, equals('finance-pc'));
      },
    );

    // ── Scenario 13 ───────────────────────────────────────────────────────────
    test(
      '13. Newly discovered device follows existing approval and monitoring workflow',
      () async {
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init();

        final discovered = DiscoveredDeviceEntity(
          id: 1,
          scanId: 1,
          ip: '10.10.20.50',
          hostname: 'ws-john',
          vendor: 'Dell Inc.',
          predictedCategory: DeviceCategory.pc,
          confidence: ClassificationConfidence.high,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        await discoveryRepo.saveDiscoveredDevice(discovered);

        // Admin approves device
        final success = await cubit.approveDevice(
          discoveredDevice: discovered,
          ownerName: 'John Doe',
          department: 'Engineering',
          deviceName: 'Dell-Precision-50',
          isMonitored: true,
        );
        expect(success, isTrue);

        // Check device inventory contains the approved device
        final devicesRes = await deviceRepo.getDevices();
        expect(devicesRes.isSuccess, isTrue);
        final saved = devicesRes.dataOrNull!.firstWhere(
          (d) => d.ip == '10.10.20.50',
        );
        expect(saved.ownerName, equals('John Doe'));
        expect(saved.department, equals('Engineering'));
        expect(saved.isMonitored, isTrue);

        await cubit.close();
      },
    );

    // ── Scenario 14 ───────────────────────────────────────────────────────────
    test(
      '14. Range-dependent filters, summaries, and CSV export use current dynamic data',
      () async {
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          validator,
        );
        await cubit.init();

        // Configure two subnets
        await cubit.addNetworkRange(cidr: '10.1.1.0/24', name: 'VLAN 1');
        await cubit.addNetworkRange(cidr: '10.1.2.0/24', name: 'VLAN 2');

        // Populate two devices across subnets
        await discoveryRepo.saveDiscoveredDevice(
          DiscoveredDeviceEntity(
            scanId: 1,
            ip: '10.1.1.5',
            hostname: 'srv-1',
            predictedCategory: DeviceCategory.server,
            confidence: ClassificationConfidence.high,
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );
        await discoveryRepo.saveDiscoveredDevice(
          DiscoveredDeviceEntity(
            scanId: 1,
            ip: '10.1.2.9',
            hostname: 'printer-2',
            predictedCategory: DeviceCategory.printer,
            confidence: ClassificationConfidence.high,
            firstSeen: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );

        // Trigger state refresh
        await cubit.init();
        var state = cubit.state as NetworkDiscoveryLoaded;
        expect(state.totalDiscovered, equals(2));

        // Filter by subnet 10.1.1.0/24
        cubit.setSubnetFilter('10.1.1.0/24');
        state = cubit.state as NetworkDiscoveryLoaded;
        expect(state.filteredDevices.length, equals(1));
        expect(state.filteredDevices.first.ip, equals('10.1.1.5'));

        // CSV export contains filtered device
        final csv = cubit.exportToCsv();
        expect(csv, contains('10.1.1.5'));
        expect(csv, isNot(contains('10.1.2.9')));

        await cubit.close();
      },
    );

    // ── Scenario 15 ───────────────────────────────────────────────────────────
    test(
      '15. Backward compatibility: legacy string array authorizedRangesJson parses correctly',
      () async {
        // Simulate existing installation data stored in Drift before migration
        // In old schema, authorizedRangesJson had '["10.0.0.0/24", "172.16.0.0/24"]'
        await db
            .into(db.discoveryConfigurations)
            .insert(
              DiscoveryConfigurationsCompanion.insert(
                authorizedRangesJson: Value('["10.0.0.0/24", "172.16.0.0/24"]'),
                enabledStrategiesJson: Value('["icmp", "arp"]'),
                maxConcurrency: Value(20),
                timeoutSeconds: Value(2),
              ),
            );

        // DiscoveryRepository must transparently migrate/parse string array into List<NetworkRange>
        final configRes = await discoveryRepo.getConfig();
        expect(configRes.isSuccess, isTrue);
        final config = configRes.dataOrNull!;

        expect(config.networkRanges.length, equals(2));
        expect(config.networkRanges[0].cidr, equals('10.0.0.0/24'));
        expect(config.networkRanges[1].cidr, equals('172.16.0.0/24'));
        expect(
          config.authorizedRanges,
          equals(['10.0.0.0/24', '172.16.0.0/24']),
        );
      },
    );
  });
}
