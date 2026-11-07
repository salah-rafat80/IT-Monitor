import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/factories/data/repositories/factory_repository_impl.dart';
import 'package:it_network_monitor/features/factories/domain/entities/factory_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovered_device_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_config_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_scan_job.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/network_range.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';

class TestIcmpStrategy extends IcmpDiscoveryStrategy {
  TestIcmpStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class TestArpStrategy extends ArpDiscoveryStrategy {
  TestArpStrategy(super.lookup) : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class TestDnsStrategy extends DnsHostnameStrategy {
  TestDnsStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class TestTcpStrategy extends TcpProbeDiscoveryStrategy {
  TestTcpStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class TestOnvifStrategy extends OnvifDiscoveryStrategy {
  TestOnvifStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class TestMdnsStrategy extends MdnsSsdpDiscoveryStrategy {
  TestMdnsStrategy() : super();
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

void main() {
  group('Multi-Factory Architecture & Full Data Isolation Tests', () {
    late AppDatabase db;
    late FactoryRepositoryImpl factoryRepo;
    late DeviceRepositoryImpl deviceRepo;
    late InfrastructureRepositoryImpl infraRepo;
    late DiscoveryRepositoryImpl discoveryRepo;
    late DiscoveryCoordinator coordinator;

    setUp(() async {
      AppConfig.enforceReleaseModeSecurity = false;
      AppConfig.resetForTesting(mode: AppRunMode.standaloneDevelopment);

      db = AppDatabase.forTesting(NativeDatabase.memory());
      final migrator = db.createMigrator();
      await migrator.createAll();
      await db.ensureDefaultFactoriesSeeded();

      factoryRepo = FactoryRepositoryImpl(db);
      deviceRepo = DeviceRepositoryImpl(db);
      infraRepo = InfrastructureRepositoryImpl(db);
      discoveryRepo = DiscoveryRepositoryImpl(db);

      final validator = NetworkRangeValidator();
      final vendorLookup = MacVendorLookup();
      final classifier = DeviceClassificationEngine(vendorLookup);

      coordinator = DiscoveryCoordinator(
        discoveryRepo,
        deviceRepo,
        validator,
        classifier,
        vendorLookup,
        TestIcmpStrategy(),
        TestArpStrategy(vendorLookup),
        TestDnsStrategy(),
        TestTcpStrategy(),
        TestOnvifStrategy(),
        TestMdnsStrategy(),
      );
    });

    tearDown(() async {
      await db.close();
      AppConfig.resetForTesting(mode: AppRunMode.standaloneDevelopment);
    });

    test(
      'Scenario 1: BNF, RNF, and UNASSIGNED are seeded idempotently without duplicates',
      () async {
        final res1 = await factoryRepo.getFactories();
        expect(res1.isSuccess, isTrue);
        final factories1 = res1.dataOrNull!;
        expect(factories1.any((f) => f.id == 'bnf' && f.code == 'BNF'), isTrue);
        expect(factories1.any((f) => f.id == 'rnf' && f.code == 'RNF'), isTrue);
        expect(factories1.any((f) => f.id == 'unassigned'), isTrue);

        // Re-run migration / seeding callback
        await db.migration.onUpgrade(db.createMigrator(), 11, 12);

        final res2 = await factoryRepo.getFactories();
        final factories2 = res2.dataOrNull!;
        final bnfCount = factories2.where((f) => f.id == 'bnf').length;
        final rnfCount = factories2.where((f) => f.id == 'rnf').length;
        expect(bnfCount, equals(1));
        expect(rnfCount, equals(1));
      },
    );

    test(
      'Scenario 2: A factory can own multiple dynamically added ranges',
      () async {
        final bnfRange1 = NetworkRange.parse(
          '10.10.20.0/24',
          factoryId: 'bnf',
          name: 'BNF Production Floor',
        )!;
        final bnfRange2 = NetworkRange.parse(
          '10.10.30.0/24',
          factoryId: 'bnf',
          name: 'BNF Logistics & Warehousing',
        )!;

        final config = DiscoveryConfigEntity(
          networkRanges: [bnfRange1, bnfRange2],
          updatedAt: DateTime.now(),
        );
        await discoveryRepo.saveConfig(config);

        final bnfRangesRes = await discoveryRepo.getRanges(factoryId: 'bnf');
        expect(bnfRangesRes.isSuccess, isTrue);
        final bnfRanges = bnfRangesRes.dataOrNull!;
        expect(bnfRanges.length, equals(2));
        expect(
          bnfRanges.map((r) => r.cidr),
          containsAll(['10.10.20.0/24', '10.10.30.0/24']),
        );
      },
    );

    test(
      'Scenario 3: A new range saved for BNF does not appear in RNF range list',
      () async {
        final bnfRange = NetworkRange.parse(
          '10.10.20.0/24',
          factoryId: 'bnf',
          name: 'BNF Subnet',
        )!;
        final rnfRange = NetworkRange.parse(
          '192.168.40.0/24',
          factoryId: 'rnf',
          name: 'RNF Subnet',
        )!;

        await discoveryRepo.saveConfig(
          DiscoveryConfigEntity(
            networkRanges: [bnfRange, rnfRange],
            updatedAt: DateTime.now(),
          ),
        );

        final bnfOnly = (await discoveryRepo.getRanges(
          factoryId: 'bnf',
        )).dataOrNull!;
        final rnfOnly = (await discoveryRepo.getRanges(
          factoryId: 'rnf',
        )).dataOrNull!;

        expect(bnfOnly.every((r) => r.factoryId == 'bnf'), isTrue);
        expect(bnfOnly.any((r) => r.cidr == '192.168.40.0/24'), isFalse);

        expect(rnfOnly.every((r) => r.factoryId == 'rnf'), isTrue);
        expect(rnfOnly.any((r) => r.cidr == '10.10.20.0/24'), isFalse);
      },
    );

    test(
      'Scenario 4: The exact same CIDR and IP can exist across different factories without cross-factory conflict',
      () async {
        final bnfRange = NetworkRange.parse(
          '192.168.1.0/24',
          factoryId: 'bnf',
          name: 'BNF Office',
        )!;
        final rnfRange = NetworkRange.parse(
          '192.168.1.0/24',
          factoryId: 'rnf',
          name: 'RNF Office',
        )!;

        expect(bnfRange.id, isNot(equals(rnfRange.id)));

        // Add device with same IP 192.168.1.50 to BNF
        final devBnf = DeviceEntity(
          id: 0,
          factoryId: 'bnf',
          name: 'BNF Core Workstation',
          type: DeviceType.pc,
          ip: '192.168.1.50',
          ownerName: 'BNF Operator',
          department: 'Operations',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final bnfAddRes = await deviceRepo.addDevice(devBnf);
        expect(bnfAddRes.isSuccess, isTrue);

        // Add device with same IP 192.168.1.50 to RNF
        final devRnf = DeviceEntity(
          id: 0,
          factoryId: 'rnf',
          name: 'RNF Core Workstation',
          type: DeviceType.pc,
          ip: '192.168.1.50',
          ownerName: 'RNF Operator',
          department: 'Operations',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final rnfAddRes = await deviceRepo.addDevice(devRnf);
        expect(rnfAddRes.isSuccess, isTrue);

        // Verify querying by factory yields exactly one device without merging
        final bnfDevices = (await deviceRepo.getDevices(
          factoryId: 'bnf',
        )).dataOrNull!;
        final rnfDevices = (await deviceRepo.getDevices(
          factoryId: 'rnf',
        )).dataOrNull!;
        expect(bnfDevices.length, equals(1));
        expect(bnfDevices.first.name, equals('BNF Core Workstation'));
        expect(rnfDevices.length, equals(1));
        expect(rnfDevices.first.name, equals('RNF Core Workstation'));

        // Inserting duplicate within the SAME factory is rejected
        final duplicateBnf = await deviceRepo.addDevice(
          devBnf.copyWith(name: 'Duplicate'),
        );
        expect(duplicateBnf.isFailure, isTrue);
      },
    );

    test(
      'Scenario 5 & 6: Discovery scan respects factoryId and resolves only authorized ranges',
      () async {
        final bnfRange = NetworkRange.parse(
          '10.10.20.0/24',
          factoryId: 'bnf',
          isEnabled: true,
        )!;
        final rnfRange = NetworkRange.parse(
          '192.168.40.0/24',
          factoryId: 'rnf',
          isEnabled: true,
        )!;

        final config = DiscoveryConfigEntity(
          networkRanges: [bnfRange, rnfRange],
          updatedAt: DateTime.now(),
        );
        await discoveryRepo.saveConfig(config);

        // Trigger BNF scan
        final bnfJobRes = await coordinator.startScan(
          factoryId: 'bnf',
          requestedRanges: ['10.10.20.0/24'],
        );
        expect(bnfJobRes.isSuccess, isTrue);
        final bnfJob = bnfJobRes.dataOrNull!;
        expect(bnfJob.factoryId, equals('bnf'));
        expect(bnfJob.targetRanges, equals(['10.10.20.0/24']));

        await coordinator.cancelScan();

        // Trigger RNF scan
        final rnfJobRes = await coordinator.startScan(
          factoryId: 'rnf',
          requestedRanges: ['192.168.40.0/24'],
        );
        expect(rnfJobRes.isSuccess, isTrue);
        final rnfJob = rnfJobRes.dataOrNull!;
        expect(rnfJob.factoryId, equals('rnf'));
        expect(rnfJob.targetRanges, equals(['192.168.40.0/24']));
      },
    );

    test(
      'Scenario 7: Scan job records its factory and stable ranges used',
      () async {
        final range = NetworkRange.parse(
          '10.10.20.0/24',
          factoryId: 'bnf',
          isEnabled: true,
        )!;
        await discoveryRepo.saveConfig(
          DiscoveryConfigEntity(
            networkRanges: [range],
            updatedAt: DateTime.now(),
          ),
        );

        final job = DiscoveryScanJob(
          factoryId: 'bnf',
          targetRanges: ['10.10.20.0/24'],
          startedAt: DateTime.now(),
        );
        final scanIdRes = await discoveryRepo.createScanJob(job);
        expect(scanIdRes.isSuccess, isTrue);

        final latestJob = (await discoveryRepo.getLatestScanJob(
          factoryId: 'bnf',
        )).dataOrNull;
        expect(latestJob?.factoryId, equals('bnf'));
        expect(latestJob?.targetRanges, contains('10.10.20.0/24'));
      },
    );

    test(
      'Scenario 8: Discovered devices inherit factory association',
      () async {
        final bnfDevice = DiscoveredDeviceEntity(
          id: 0,
          scanId: 1,
          factoryId: 'bnf',
          ip: '10.10.20.15',
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        final rnfDevice = DiscoveredDeviceEntity(
          id: 0,
          scanId: 2,
          factoryId: 'rnf',
          ip: '192.168.40.15',
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );

        await discoveryRepo.saveDiscoveredDevice(bnfDevice);
        await discoveryRepo.saveDiscoveredDevice(rnfDevice);

        final bnfDiscovered = (await discoveryRepo.getDiscoveredDevices(
          factoryId: 'bnf',
        )).dataOrNull!;
        final rnfDiscovered = (await discoveryRepo.getDiscoveredDevices(
          factoryId: 'rnf',
        )).dataOrNull!;

        expect(bnfDiscovered.length, equals(1));
        expect(bnfDiscovered.first.ip, equals('10.10.20.15'));
        expect(bnfDiscovered.first.factoryId, equals('bnf'));

        expect(rnfDiscovered.length, equals(1));
        expect(rnfDiscovered.first.ip, equals('192.168.40.15'));
        expect(rnfDiscovered.first.factoryId, equals('rnf'));
      },
    );

    test('Scenario 9: Infrastructure respects factory scope', () async {
      // 1. Infrastructure
      final now = DateTime.now();
      final bnfSwitch = UniFiDeviceEntity(
        id: 0,
        factoryId: 'bnf',
        name: 'BNF Switch 1',
        ip: '10.10.20.2',
        role: UniFiDeviceRole.switchDevice,
        isCriticalInfrastructure: true,
        createdAt: now,
      );
      final rnfSwitch = UniFiDeviceEntity(
        id: 0,
        factoryId: 'rnf',
        name: 'RNF Switch 1',
        ip: '192.168.40.2',
        role: UniFiDeviceRole.switchDevice,
        isCriticalInfrastructure: true,
        createdAt: now,
      );
      await infraRepo.saveInfrastructureDevice(bnfSwitch);
      await infraRepo.saveInfrastructureDevice(rnfSwitch);

      final bnfInfra = (await infraRepo.getInfrastructureDevices(
        factoryId: 'bnf',
      )).dataOrNull!;
      expect(bnfInfra.length, equals(1));
      expect(bnfInfra.first.name, equals('BNF Switch 1'));
    });

    test(
      'Scenario 10: All-factories dashboard aggregates correctly without merging records',
      () async {
        final devBnf = DeviceEntity(
          id: 0,
          factoryId: 'bnf',
          name: 'BNF PC',
          type: DeviceType.pc,
          ip: '10.10.20.10',
          ownerName: 'BNF User',
          department: 'IT',
          createdAt: DateTime.now(),
        );
        final devRnf = DeviceEntity(
          id: 0,
          factoryId: 'rnf',
          name: 'RNF PC',
          type: DeviceType.pc,
          ip: '192.168.40.10',
          ownerName: 'RNF User',
          department: 'IT',
          createdAt: DateTime.now(),
        );
        await deviceRepo.addDevice(devBnf);
        await deviceRepo.addDevice(devRnf);

        // Consolidated query (factoryId: null)
        final allDevices = (await deviceRepo.getDevices()).dataOrNull!;
        expect(allDevices.length, equals(2));
        expect(
          allDevices.map((d) => d.factoryId).toSet(),
          equals({'bnf', 'rnf'}),
        );
      },
    );

    test(
      'Scenario 11: Cross-factory duplicate IP insertion within same factory is rejected, different factory is accepted',
      () async {
        final dev1 = DeviceEntity(
          id: 0,
          factoryId: 'bnf',
          name: 'BNF Dev',
          type: DeviceType.pc,
          ip: '10.10.20.99',
          ownerName: 'User',
          department: 'IT',
          createdAt: DateTime.now(),
        );
        expect((await deviceRepo.addDevice(dev1)).isSuccess, isTrue);

        // Attempt duplicate in BNF
        final dev1Dup = dev1.copyWith(name: 'BNF Dev 2');
        final dupRes = await deviceRepo.addDevice(dev1Dup);
        expect(dupRes.isFailure, isTrue);

        // Same IP in RNF succeeds
        final devRnf = dev1.copyWith(factoryId: 'rnf', name: 'RNF Dev');
        final rnfRes = await deviceRepo.addDevice(devRnf);
        expect(rnfRes.isSuccess, isTrue);
      },
    );

    test(
      'Scenario 12: Range changes persist across configuration reload',
      () async {
        final range = NetworkRange.parse(
          '10.10.50.0/24',
          factoryId: 'bnf',
          name: 'BNF Expansion',
        )!;
        await discoveryRepo.saveConfig(
          DiscoveryConfigEntity(
            networkRanges: [range],
            updatedAt: DateTime.now(),
          ),
        );

        // Read back fresh from database
        final freshConfig = (await discoveryRepo.getConfig()).dataOrNull!;
        final bnfRanges = freshConfig.getRangesForFactory('bnf');
        expect(bnfRanges.length, equals(1));
        expect(bnfRanges.first.cidr, equals('10.10.50.0/24'));
      },
    );

    test(
      'Scenario 13: Disabled ranges are excluded from active discovery target resolution',
      () async {
        final enabledRange = NetworkRange.parse(
          '10.10.20.0/24',
          factoryId: 'bnf',
          isEnabled: true,
        )!;
        final disabledRange = NetworkRange.parse(
          '10.10.30.0/24',
          factoryId: 'bnf',
          isEnabled: false,
        )!;

        final config = DiscoveryConfigEntity(
          networkRanges: [enabledRange, disabledRange],
          updatedAt: DateTime.now(),
        );
        final activeBnfRanges = config.getAuthorizedRangesForFactory('bnf');
        expect(activeBnfRanges, equals(['10.10.20.0/24']));
        expect(activeBnfRanges, isNot(contains('10.10.30.0/24')));
      },
    );

    test(
      'Scenario 14: Invalid range CIDR is rejected by parser and validator',
      () async {
        final validator = NetworkRangeValidator();
        final invalid = validator.validateSingleRange('999.999.999.999/24');
        expect(invalid, isNull);

        final valid = validator.validateSingleRange('10.10.20.0/24');
        expect(valid, isNotNull);
        expect(valid!.cidr, equals('10.10.20.0/24'));
      },
    );

    test(
      'Scenario 15: Legacy ranges without factoryId default safely to unassigned',
      () async {
        const legacyJson = '[{"cidr": "172.16.0.0/24", "isEnabled": true}]';
        await db
            .into(db.discoveryConfigurations)
            .insert(
              DiscoveryConfigurationsCompanion.insert(
                authorizedRangesJson: const drift.Value(legacyJson),
              ),
            );

        // Trigger v12 migration step 9
        await db.migration.onUpgrade(db.createMigrator(), 11, 12);

        final cfgRow = await db.select(db.discoveryConfigurations).getSingle();
        final decoded = jsonDecode(cfgRow.authorizedRangesJson) as List;
        expect(decoded.first['factoryId'], equals('unassigned'));
      },
    );

    test(
      'Scenario 16: Overlapping ranges in same factory calculate deduplicated host counts',
      () async {
        final validator = NetworkRangeValidator();
        final range1 = NetworkRange.parse('192.168.1.0/24', factoryId: 'bnf')!;
        final range2 = NetworkRange.parse('192.168.1.0/24', factoryId: 'bnf')!;

        final hostCount = validator.calculateTotalUsableHosts([range1, range2]);
        expect(hostCount, equals(254)); // Not 508
      },
    );

    test(
      'Scenario 17: Generic factory creation allows adding new sites without code changes',
      () async {
        final newFactory = FactoryEntity(
          id: FactoryEntity.generateId('KNF'),
          code: 'KNF',
          name: 'KNF Industrial Plant',
          createdAt: DateTime.now(),
        );
        final createRes = await factoryRepo.createFactory(newFactory);
        expect(createRes.isSuccess, isTrue);

        final allFactories = (await factoryRepo.getFactories()).dataOrNull!;
        expect(allFactories.any((f) => f.code == 'KNF'), isTrue);

        // Can add ranges immediately for KNF
        final knfRange = NetworkRange.parse(
          '172.20.10.0/24',
          factoryId: newFactory.id,
          name: 'KNF Primary LAN',
        )!;
        final config = DiscoveryConfigEntity(
          networkRanges: [knfRange],
          updatedAt: DateTime.now(),
        );
        await discoveryRepo.saveConfig(config);

        final knfRanges = (await discoveryRepo.getRanges(
          factoryId: newFactory.id,
        )).dataOrNull!;
        expect(knfRanges.length, equals(1));
        expect(knfRanges.first.cidr, equals('172.20.10.0/24'));
      },
    );

    test(
      'Scenario 18: Deactivating a factory preserves its devices and data intact',
      () async {
        final dev = DeviceEntity(
          id: 0,
          factoryId: 'rnf',
          name: 'RNF Legacy Machine',
          type: DeviceType.server,
          ip: '192.168.40.80',
          ownerName: 'Facility',
          department: 'Plant',
          createdAt: DateTime.now(),
        );
        await deviceRepo.addDevice(dev);

        // Deactivate RNF
        final rnfFactory = (await factoryRepo.getFactoryById(
          'rnf',
        )).dataOrNull!;
        await factoryRepo.updateFactory(rnfFactory.copyWith(isActive: false));

        // Device remains intact and queryable
        final devices = (await deviceRepo.getDevices(
          factoryId: 'rnf',
        )).dataOrNull!;
        expect(devices.length, equals(1));
        expect(devices.first.name, equals('RNF Legacy Machine'));
      },
    );
  });
}
