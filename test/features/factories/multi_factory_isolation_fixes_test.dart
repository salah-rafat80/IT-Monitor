import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/factories/data/repositories/factory_repository_impl.dart';
import 'package:it_network_monitor/features/factories/domain/repositories/factory_repository.dart';
import 'package:it_network_monitor/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/incidents/domain/repositories/incident_repository.dart';
import 'package:it_network_monitor/features/incidents/presentation/bloc/incidents_cubit.dart';
import 'package:it_network_monitor/features/incidents/presentation/bloc/incidents_state.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/repositories/infrastructure_repository.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/presentation/services/monitoring_service_server.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/arp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/dns_hostname_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/mdns_ssdp_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/onvif_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/tcp_probe_discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/data/repositories/discovery_repository_impl.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_config_entity.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/network_range.dart';
import 'package:it_network_monitor/features/network_discovery/domain/repositories/discovery_repository.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_strategy.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_cubit.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_state.dart';
import 'package:it_network_monitor/features/reports/data/repositories/report_repository_impl.dart';
import 'package:it_network_monitor/features/reports/domain/entities/report_entity.dart';
import 'package:it_network_monitor/features/reports/presentation/bloc/reports_cubit.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/domain/services/topology_grouper.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_cubit.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_state.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

class MockSuccessIcmpStrategy extends IcmpDiscoveryStrategy {
  final Set<String> respondingIps;
  MockSuccessIcmpStrategy(this.respondingIps);

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    if (respondingIps.contains(targetIp)) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        evidenceDetails: '64 bytes from target: icmp_seq=1 ttl=64 time=1.2 ms',
      );
    }
    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'Host unreachable',
    );
  }
}

class MockEmptyArpStrategy extends ArpDiscoveryStrategy {
  MockEmptyArpStrategy(super.lookup);
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class MockEmptyDnsStrategy extends DnsHostnameStrategy {
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class MockEmptyTcpStrategy extends TcpProbeDiscoveryStrategy {
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class MockEmptyOnvifStrategy extends OnvifDiscoveryStrategy {
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

class MockEmptyMdnsStrategy extends MdnsSsdpDiscoveryStrategy {
  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async =>
      StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'err',
      );
}

void main() {
  group('Multi-Factory Isolation Audit & Integration Regression Suite', () {
    late AppDatabase db;
    late AuditLogRepositoryImpl auditRepo;
    late AuthRepositoryImpl authRepo;
    late FactoryRepositoryImpl factoryRepo;
    late DeviceRepositoryImpl deviceRepo;
    late InfrastructureRepositoryImpl infraRepo;
    late IncidentRepositoryImpl incidentRepo;
    late MonitoringRepositoryImpl monitoringRepo;
    late DiscoveryRepositoryImpl discoveryRepo;
    late ReportRepositoryImpl reportRepo;
    late NetworkRangeValidator rangeValidator;
    late DiscoveryCoordinator coordinator;

    Directory? tempDir;
    MonitoringServiceServer? server;
    int? serverPort;
    String? serverToken;

    final bnfRange = NetworkRange.parse(
      '10.10.20.0/24',
      id: 'range_bnf_10_10_20_0_24',
      factoryId: 'bnf',
      name: 'BNF Core VLAN',
      isEnabled: true,
    )!;

    final bnfDisabledRange = NetworkRange.parse(
      '10.10.30.0/24',
      id: 'range_bnf_10_10_30_0_24',
      factoryId: 'bnf',
      name: 'BNF Disabled Scope',
      isEnabled: false,
    )!;

    final rnfRange = NetworkRange.parse(
      '192.168.40.0/24',
      id: 'range_rnf_192_168_40_0_24',
      factoryId: 'rnf',
      name: 'RNF Production VLAN',
      isEnabled: true,
    )!;

    setUp(() async {
      AppConfig.enforceReleaseModeSecurity = false;
      AppConfig.resetForTesting(mode: AppRunMode.standaloneDevelopment);

      db = AppDatabase.forTesting(NativeDatabase.memory());
      final migrator = db.createMigrator();
      await migrator.createAll();
      await db.ensureDefaultFactoriesSeeded();

      auditRepo = AuditLogRepositoryImpl(db);
      authRepo = AuthRepositoryImpl(db, auditRepo);
      await authRepo.createInitialAdmin(
        username: 'admin',
        password: 'Password123',
      );

      factoryRepo = FactoryRepositoryImpl(db);
      deviceRepo = DeviceRepositoryImpl(db, auditRepo, authRepo);
      infraRepo = InfrastructureRepositoryImpl(db, auditRepo, authRepo);
      incidentRepo = IncidentRepositoryImpl(db, auditRepo);
      monitoringRepo = MonitoringRepositoryImpl(db);
      discoveryRepo = DiscoveryRepositoryImpl(db);
      reportRepo = ReportRepositoryImpl(db);
      rangeValidator = NetworkRangeValidator();

      final vendorLookup = MacVendorLookup();
      final classifier = DeviceClassificationEngine(vendorLookup);

      coordinator = DiscoveryCoordinator(
        discoveryRepo,
        deviceRepo,
        rangeValidator,
        classifier,
        vendorLookup,
        MockSuccessIcmpStrategy({'10.10.20.15', '192.168.40.25'}),
        MockEmptyArpStrategy(vendorLookup),
        MockEmptyDnsStrategy(),
        MockEmptyTcpStrategy(),
        MockEmptyOnvifStrategy(),
        MockEmptyMdnsStrategy(),
        infraRepo,
        factoryRepo,
      );

      // Save initial authoritative discovery config
      await discoveryRepo.saveConfig(
        DiscoveryConfigEntity(
          networkRanges: [bnfRange, bnfDisabledRange, rnfRange],
          updatedAt: DateTime.now(),
        ),
      );
    });

    Future<void> ensureServerRunning() async {
      if (server != null) return;
      tempDir = await Directory.systemTemp.createTemp('it_monitor_iso_test_');

      if (getIt.isRegistered<AppDatabase>()) {
        await getIt.unregister<AppDatabase>();
      }
      getIt.registerSingleton<AppDatabase>(db);

      if (getIt.isRegistered<FactoryRepository>()) {
        await getIt.unregister<FactoryRepository>();
      }
      getIt.registerSingleton<FactoryRepository>(factoryRepo);

      if (getIt.isRegistered<DiscoveryRepository>()) {
        await getIt.unregister<DiscoveryRepository>();
      }
      getIt.registerSingleton<DiscoveryRepository>(discoveryRepo);

      if (getIt.isRegistered<DiscoveryCoordinator>()) {
        await getIt.unregister<DiscoveryCoordinator>();
      }
      getIt.registerSingleton<DiscoveryCoordinator>(coordinator);

      if (getIt.isRegistered<DeviceRepository>()) {
        await getIt.unregister<DeviceRepository>();
      }
      getIt.registerSingleton<DeviceRepository>(deviceRepo);

      if (getIt.isRegistered<InfrastructureRepository>()) {
        await getIt.unregister<InfrastructureRepository>();
      }
      getIt.registerSingleton<InfrastructureRepository>(infraRepo);

      if (getIt.isRegistered<IncidentRepository>()) {
        await getIt.unregister<IncidentRepository>();
      }
      getIt.registerSingleton<IncidentRepository>(incidentRepo);

      if (getIt.isRegistered<MonitoringRepository>()) {
        await getIt.unregister<MonitoringRepository>();
      }
      getIt.registerSingleton<MonitoringRepository>(monitoringRepo);

      server = MonitoringServiceServer(
        port: 0,
        useTls: false,
        isDevelopment: true,
        customDataDir: tempDir!.path,
      );
      await server!.start();
      serverPort = server!.boundPort;
      serverToken = server!.trustedClientToken;
    }

    Future<Map<String, dynamic>> postJson(
      String path,
      Map<String, dynamic> body,
    ) async {
      await ensureServerRunning();
      final client = HttpClient();
      try {
        final req = await client.postUrl(
          Uri.parse('http://127.0.0.1:$serverPort$path'),
        );
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serverToken');
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.add(utf8.encode(jsonEncode(body)));
        final resp = await req.close();
        final bodyStr = await utf8.decoder.bind(resp).join();
        return {
          'statusCode': resp.statusCode,
          'body': bodyStr.isNotEmpty
              ? jsonDecode(bodyStr)
              : <String, dynamic>{},
        };
      } finally {
        client.close();
      }
    }

    tearDown(() async {
      if (server != null) {
        await server!.stop();
        server = null;
      }
      if (getIt.isRegistered<DiscoveryCoordinator>()) {
        await getIt.unregister<DiscoveryCoordinator>();
      }
      if (getIt.isRegistered<DiscoveryRepository>()) {
        await getIt.unregister<DiscoveryRepository>();
      }
      if (getIt.isRegistered<FactoryRepository>()) {
        await getIt.unregister<FactoryRepository>();
      }
      if (getIt.isRegistered<InfrastructureRepository>()) {
        await getIt.unregister<InfrastructureRepository>();
      }
      if (getIt.isRegistered<DeviceRepository>()) {
        await getIt.unregister<DeviceRepository>();
      }
      if (getIt.isRegistered<IncidentRepository>()) {
        await getIt.unregister<IncidentRepository>();
      }
      if (getIt.isRegistered<MonitoringRepository>()) {
        await getIt.unregister<MonitoringRepository>();
      }
      if (getIt.isRegistered<AppDatabase>()) {
        await getIt.unregister<AppDatabase>();
      }

      if (tempDir != null && tempDir!.existsSync()) {
        try {
          await tempDir!.delete(recursive: true);
        } catch (_) {}
      }
      await db.close();
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 1. All Factories mode cannot launch a scan without explicit factory selection
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '1. All Factories mode cannot launch a scan without explicit factory selection',
      () async {
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          rangeValidator,
        );
        await cubit.init();

        // Ensure All Factories mode (activeFactoryId == null)
        await cubit.setFactory(null);

        await cubit.startScan();
        expect(cubit.state, isA<NetworkDiscoveryLoaded>());
        final loaded = cubit.state as NetworkDiscoveryLoaded;
        expect(
          loaded.errorMessage,
          contains(
            'A specific factory must be selected before launching a discovery scan',
          ),
        );

        // Coordinator level check with factoryId: null
        final coordRes = await coordinator.startScan(factoryId: null);
        expect(coordRes.isFailure, isTrue);
        expect(
          coordRes.failureOrNull?.message,
          contains('Consolidated or unassigned scans are not permitted'),
        );

        await cubit.close();
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Selecting BNF and submitting an RNF range is rejected by the coordinator
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '2. Selecting BNF and submitting an RNF range is rejected by the coordinator',
      () async {
        final res = await coordinator.startScan(
          factoryId: 'bnf',
          requestedRanges: [rnfRange.cidr],
        );
        expect(res.isFailure, isTrue);
        expect(
          res.failureOrNull?.message,
          contains(
            'belongs to another factory ("rnf") and cannot be scanned under factory "bnf"',
          ),
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 3. The service API rejects a requested range owned by another factory
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '3. The service API rejects a requested range owned by another factory',
      () async {
        final resp = await postJson('/api/discovery/start', {
          'factoryId': 'bnf',
          'requestedRanges': [rnfRange.cidr],
        });
        expect(resp['statusCode'], equals(400));
        expect(resp['body']['error'], contains('belongs to another factory'));
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 4. A disabled range cannot be scanned through a manually constructed API request
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '4. A disabled range cannot be scanned through a manually constructed API request',
      () async {
        // Coordinator level check
        final coordRes = await coordinator.startScan(
          factoryId: 'bnf',
          requestedRanges: [bnfDisabledRange.cidr],
        );
        expect(coordRes.isFailure, isTrue);
        expect(
          coordRes.failureOrNull?.message,
          contains('disabled for factory "bnf" and cannot be scanned'),
        );

        // Service API level check
        final resp = await postJson('/api/discovery/start', {
          'factoryId': 'bnf',
          'requestedRanges': [bnfDisabledRange.cidr],
        });
        expect(resp['statusCode'], equals(400));
        expect(resp['body']['error'], contains('disabled'));
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 5. An unregistered but syntactically valid CIDR cannot bypass range authorization
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '5. An unregistered but syntactically valid CIDR cannot bypass range authorization',
      () async {
        const unregisteredCidr = '10.99.99.0/24';

        final res = await coordinator.startScan(
          factoryId: 'bnf',
          requestedRanges: [unregisteredCidr],
        );
        expect(res.isFailure, isTrue);
        expect(
          res.failureOrNull?.message,
          contains('is not registered for factory "bnf"'),
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 6. The scan job factory ID matches the factory that owns every scanned range
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '6. The scan job factory ID matches the factory that owns every scanned range',
      () async {
        final res = await coordinator.startScan(
          factoryId: 'bnf',
          requestedRanges: [bnfRange.cidr],
          maxConcurrency: 1,
          timeoutSeconds: 1,
        );
        expect(res.isSuccess, isTrue);
        final job = res.dataOrNull!;
        expect(job.factoryId, equals('bnf'));
        expect(job.targetRanges, equals([bnfRange.cidr]));

        await coordinator.cancelScan();
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Discovery results never inherit an incorrect factory ID
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '7. Discovery results never inherit an incorrect factory ID',
      () async {
        final res = await coordinator.startScan(
          factoryId: 'bnf',
          requestedRanges: [bnfRange.cidr],
          maxConcurrency: 1,
          timeoutSeconds: 1,
        );
        expect(res.isSuccess, isTrue);

        // Allow scan loop to process simulated target
        await Future.delayed(const Duration(milliseconds: 350));

        final discRes = await discoveryRepo.getDiscoveredDevices(
          factoryId: 'bnf',
        );
        expect(discRes.isSuccess, isTrue);
        final devices = discRes.dataOrNull!;
        expect(devices.isNotEmpty, isTrue);

        for (final dev in devices) {
          expect(dev.factoryId, equals('bnf'));
          expect(dev.factoryId, isNot(equals('rnf')));
          expect(dev.factoryId, isNot(equals('unassigned')));
        }

        await coordinator.cancelScan();
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 8. Opening range management in All Factories mode cannot silently add a BNF range
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '8. Opening range management in All Factories mode cannot silently add a BNF range',
      () async {
        final cubit = NetworkDiscoveryCubit(
          discoveryRepo,
          deviceRepo,
          coordinator,
          rangeValidator,
        );
        await cubit.init();

        // Ensure All Factories mode
        await cubit.setFactory(null);

        // Attempt to add range without specifying factory
        final res = await cubit.addNetworkRange(
          cidr: '10.50.0.0/24',
          name: 'Unspecified Scope',
          factoryId: 'unassigned',
        );

        // Must be kept unassigned or rejected, NEVER silently assigned to 'bnf'
        if (res.isSuccess) {
          final config = (await discoveryRepo.getConfig()).dataOrNull!;
          final added = config.networkRanges.firstWhere(
            (r) => r.cidr == '10.50.0.0/24',
          );
          expect(added.factoryId, isNot(equals('bnf')));
        }

        // Service rejects unassigned / empty factory range creation
        final resp = await postJson('/api/discovery/ranges', {
          'cidr': '10.60.0.0/24',
          'factoryId': 'unassigned',
        });
        expect(resp['statusCode'], equals(400));
        expect(
          resp['body']['error'],
          contains('valid, active factoryId is required'),
        );

        await cubit.close();
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 9. Reports for BNF exclude RNF check and incident data
    // ──────────────────────────────────────────────────────────────────────────
    test('9. Reports for BNF exclude RNF check and incident data', () async {
      final now = DateTime.now();
      // Seed BNF device & RNF device
      final bnfDev = (await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'BNF-PC',
          ip: '10.10.20.10',
          type: DeviceType.pc,
          factoryId: 'bnf',
          ownerName: 'BNF Owner',
          department: 'BNF Ops',
          createdAt: now,
        ),
      )).dataOrNull!;

      final rnfDev = (await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'RNF-PC',
          ip: '192.168.40.10',
          type: DeviceType.pc,
          factoryId: 'rnf',
          ownerName: 'RNF Owner',
          department: 'RNF Ops',
          createdAt: now,
        ),
      )).dataOrNull!;

      // Seed check results
      await monitoringRepo.saveCheckResult(
        CheckResult.success(
          deviceId: bnfDev.id,
          targetIp: '10.10.20.10',
          timestamp: now,
        ),
      );
      await monitoringRepo.saveCheckResult(
        CheckResult(
          deviceId: rnfDev.id,
          targetIp: '192.168.40.10',
          isSuccess: false,
          timestamp: now,
          failureReason: PingFailureReason.timeout,
        ),
      );

      // Seed incidents
      await incidentRepo.createIncident(
        IncidentEntity(
          id: 0,
          factoryId: 'bnf',
          deviceId: bnfDev.id,
          deviceName: 'BNF-PC',
          ownerName: 'BNF Owner',
          department: 'BNF Ops',
          deviceIp: '10.10.20.10',
          incidentType: IncidentTypeEnum.highLatency,
          severity: IncidentSeverityEnum.medium,
          status: IncidentStatusEnum.active,
          startedAt: now,
        ),
      );
      await incidentRepo.createIncident(
        IncidentEntity(
          id: 0,
          factoryId: 'rnf',
          deviceId: rnfDev.id,
          deviceName: 'RNF-PC',
          ownerName: 'RNF Owner',
          department: 'RNF Ops',
          deviceIp: '192.168.40.10',
          incidentType: IncidentTypeEnum.deviceDown,
          severity: IncidentSeverityEnum.critical,
          status: IncidentStatusEnum.active,
          startedAt: now,
        ),
      );

      final reportRes = await reportRepo.generateReport(
        ReportPeriod.last24Hours,
        factoryId: 'bnf',
      );
      expect(reportRes.isSuccess, isTrue);
      final report = reportRes.dataOrNull!;

      expect(report.totalDevices, equals(1));
      expect(report.totalCheckCount, equals(1));
      expect(report.totalIncidents, equals(1));
      expect(report.deviceUptimes.first.deviceName, equals('BNF-PC'));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 10. Reports for RNF exclude BNF data
    // ──────────────────────────────────────────────────────────────────────────
    test('10. Reports for RNF exclude BNF data', () async {
      final now = DateTime.now();
      final bnfDev = (await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'BNF-Server',
          ip: '10.10.20.20',
          type: DeviceType.server,
          factoryId: 'bnf',
          ownerName: 'Admin',
          department: 'IT',
          createdAt: now,
        ),
      )).dataOrNull!;

      final rnfDev = (await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'RNF-Server',
          ip: '192.168.40.20',
          type: DeviceType.server,
          factoryId: 'rnf',
          ownerName: 'Admin',
          department: 'IT',
          createdAt: now,
        ),
      )).dataOrNull!;

      await monitoringRepo.saveCheckResult(
        CheckResult(
          deviceId: bnfDev.id,
          targetIp: '10.10.20.20',
          isSuccess: false,
          timestamp: now,
          failureReason: PingFailureReason.timeout,
        ),
      );
      await monitoringRepo.saveCheckResult(
        CheckResult.success(
          deviceId: rnfDev.id,
          targetIp: '192.168.40.20',
          timestamp: now,
        ),
      );

      final reportRes = await reportRepo.generateReport(
        ReportPeriod.last24Hours,
        factoryId: 'rnf',
      );
      expect(reportRes.isSuccess, isTrue);
      final report = reportRes.dataOrNull!;

      expect(report.totalDevices, equals(1));
      expect(report.totalCheckCount, equals(1));
      expect(report.deviceUptimes.first.deviceName, equals('RNF-Server'));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 11. Consolidated reports include both factories without merging records
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '11. Consolidated reports include both factories without merging records',
      () async {
        final now = DateTime.now();
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'BNF-Dev-1',
            ip: '10.10.20.30',
            type: DeviceType.pc,
            factoryId: 'bnf',
            ownerName: 'Owner 1',
            department: 'IT',
            createdAt: now,
          ),
        );
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'RNF-Dev-2',
            ip: '192.168.40.30',
            type: DeviceType.pc,
            factoryId: 'rnf',
            ownerName: 'Owner 2',
            department: 'IT',
            createdAt: now,
          ),
        );

        final reportRes = await reportRepo.generateReport(
          ReportPeriod.last24Hours,
          factoryId: null,
        );
        expect(reportRes.isSuccess, isTrue);
        final report = reportRes.dataOrNull!;

        expect(report.totalDevices, equals(2));
        final names = report.deviceUptimes.map((s) => s.deviceName).toList();
        expect(names, containsAll(['BNF-Dev-1', 'RNF-Dev-2']));
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 12. Incident lists, history, and real-time subscriptions respect the selected factory
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '12. Incident lists, history, and real-time subscriptions respect the selected factory',
      () async {
        final now = DateTime.now();
        final incBnf = (await incidentRepo.createIncident(
          IncidentEntity(
            id: 0,
            factoryId: 'bnf',
            deviceId: 101,
            deviceName: 'BNF-Switch',
            ownerName: 'BNF Ops',
            department: 'IT',
            deviceIp: '10.10.20.2',
            incidentType: IncidentTypeEnum.deviceDown,
            severity: IncidentSeverityEnum.critical,
            status: IncidentStatusEnum.active,
            startedAt: now,
          ),
        )).dataOrNull!;

        final incRnf = (await incidentRepo.createIncident(
          IncidentEntity(
            id: 0,
            factoryId: 'rnf',
            deviceId: 201,
            deviceName: 'RNF-Switch',
            ownerName: 'RNF Ops',
            department: 'IT',
            deviceIp: '192.168.40.2',
            incidentType: IncidentTypeEnum.deviceDown,
            severity: IncidentSeverityEnum.critical,
            status: IncidentStatusEnum.active,
            startedAt: now,
          ),
        )).dataOrNull!;

        final incidentsCubit = IncidentsCubit(incidentRepo);

        // 1. Initialized with BNF
        await incidentsCubit.initIncidents('bnf');
        expect(incidentsCubit.state, isA<IncidentsLoaded>());
        final bnfState = incidentsCubit.state as IncidentsLoaded;
        expect(bnfState.activeIncidents.length, equals(1));
        expect(bnfState.activeIncidents.first.deviceName, equals('BNF-Switch'));

        // 2. Switched to RNF
        incidentsCubit.setFactory('rnf');
        await Future.delayed(const Duration(milliseconds: 50));
        expect(incidentsCubit.state, isA<IncidentsLoaded>());
        final rnfState = incidentsCubit.state as IncidentsLoaded;
        expect(rnfState.activeIncidents.length, equals(1));
        expect(rnfState.activeIncidents.first.deviceName, equals('RNF-Switch'));

        // 3. Switched to All Factories (consolidated)
        incidentsCubit.setFactory(null);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(incidentsCubit.state, isA<IncidentsLoaded>());
        final allState = incidentsCubit.state as IncidentsLoaded;
        expect(allState.activeIncidents.length, equals(2));

        // 4. Stream subscription respects factory filter
        final bnfStreamIncidents = await incidentRepo
            .watchActiveIncidents(factoryId: 'bnf')
            .first;
        expect(bnfStreamIncidents.length, equals(1));
        expect(bnfStreamIncidents.first.id, equals(incBnf.id));

        final rnfStreamIncidents = await incidentRepo
            .watchActiveIncidents(factoryId: 'rnf')
            .first;
        expect(rnfStreamIncidents.length, equals(1));
        expect(rnfStreamIncidents.first.id, equals(incRnf.id));

        await incidentsCubit.close();
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 13. Topology results respect the selected factory
    // ──────────────────────────────────────────────────────────────────────────
    test('13. Topology results respect the selected factory', () async {
      final now = DateTime.now();
      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'BNF-Terminal',
          ip: '10.10.20.100',
          type: DeviceType.pc,
          factoryId: 'bnf',
          ownerName: 'BNF User',
          department: 'Ops',
          createdAt: now,
        ),
      );
      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'RNF-Terminal',
          ip: '192.168.40.100',
          type: DeviceType.pc,
          factoryId: 'rnf',
          ownerName: 'RNF User',
          department: 'Ops',
          createdAt: now,
        ),
      );

      await infraRepo.saveInfrastructureDevice(
        UniFiDeviceEntity(
          id: 0,
          name: 'BNF-AP',
          ip: '10.10.20.2',
          role: UniFiDeviceRole.accessPoint,
          factoryId: 'bnf',
          createdAt: now,
        ),
      );
      await infraRepo.saveInfrastructureDevice(
        UniFiDeviceEntity(
          id: 0,
          name: 'RNF-AP',
          ip: '192.168.40.2',
          role: UniFiDeviceRole.accessPoint,
          factoryId: 'rnf',
          createdAt: now,
        ),
      );

      final topologyCubit = TopologyCubit(
        deviceRepo,
        infraRepo,
        monitoringRepo,
        TopologyGrouper(),
        EnterpriseTopologyBuilder(),
      );

      // BNF scope
      await topologyCubit.init('bnf');
      expect(topologyCubit.state, isA<TopologyLoaded>());
      final bnfLoaded = topologyCubit.state as TopologyLoaded;
      final bnfTitles =
          bnfLoaded.enterpriseGraph?.nodes.values
              .map((n) => n.title)
              .toList() ??
          [];
      expect(bnfTitles, containsAll(['BNF-Terminal', 'BNF-AP']));
      expect(bnfTitles, isNot(contains('RNF-Terminal')));
      expect(bnfTitles, isNot(contains('RNF-AP')));

      // RNF scope
      topologyCubit.setFactory('rnf');
      await Future.delayed(const Duration(milliseconds: 50));
      final rnfLoaded = topologyCubit.state as TopologyLoaded;
      final rnfTitles =
          rnfLoaded.enterpriseGraph?.nodes.values
              .map((n) => n.title)
              .toList() ??
          [];
      expect(rnfTitles, containsAll(['RNF-Terminal', 'RNF-AP']));
      expect(rnfTitles, isNot(contains('BNF-Terminal')));
      expect(rnfTitles, isNot(contains('BNF-AP')));

      // All Factories scope
      topologyCubit.setFactory(null);
      await Future.delayed(const Duration(milliseconds: 50));
      final allLoaded = topologyCubit.state as TopologyLoaded;
      final allTitles =
          allLoaded.enterpriseGraph?.nodes.values
              .map((n) => n.title)
              .toList() ??
          [];
      expect(
        allTitles,
        containsAll(['BNF-Terminal', 'BNF-AP', 'RNF-Terminal', 'RNF-AP']),
      );

      await topologyCubit.close();
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 14. Changing the selected factory refreshes every relevant feature
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '14. Changing the selected factory refreshes every relevant feature',
      () async {
        final reportsCubit = ReportsCubit(reportRepo);
        final incidentsCubit = IncidentsCubit(incidentRepo);
        final topologyCubit = TopologyCubit(
          deviceRepo,
          infraRepo,
          monitoringRepo,
          TopologyGrouper(),
          EnterpriseTopologyBuilder(),
        );

        await reportsCubit.loadReport(ReportPeriod.last24Hours, 'bnf');
        await incidentsCubit.initIncidents('bnf');
        await topologyCubit.init('bnf');

        expect(reportsCubit.currentFactoryId, equals('bnf'));
        expect(incidentsCubit.currentFactoryId, equals('bnf'));
        expect(topologyCubit.currentFactoryId, equals('bnf'));

        // Simulate global factory change to RNF
        reportsCubit.setFactory('rnf');
        incidentsCubit.setFactory('rnf');
        topologyCubit.setFactory('rnf');

        expect(reportsCubit.currentFactoryId, equals('rnf'));
        expect(incidentsCubit.currentFactoryId, equals('rnf'));
        expect(topologyCubit.currentFactoryId, equals('rnf'));

        await Future.delayed(const Duration(milliseconds: 50));

        await reportsCubit.close();
        await incidentsCubit.close();
        await topologyCubit.close();
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 15. Concurrent range updates from different clients do not overwrite one another
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '15. Concurrent range updates from different clients do not overwrite one another',
      () async {
        final rangeBnfNew = NetworkRange.parse(
          '10.10.88.0/24',
          id: 'range_bnf_10_10_88_0_24',
          factoryId: 'bnf',
          name: 'BNF New Scope',
          isEnabled: true,
        )!;

        final rangeRnfNew = NetworkRange.parse(
          '192.168.99.0/24',
          id: 'range_rnf_192_168_99_0_24',
          factoryId: 'rnf',
          name: 'RNF New Scope',
          isEnabled: true,
        )!;

        // Launch simultaneous additions
        final results = await Future.wait([
          discoveryRepo.addRange(rangeBnfNew),
          discoveryRepo.addRange(rangeRnfNew),
        ]);

        expect(results[0].isSuccess, isTrue);
        expect(results[1].isSuccess, isTrue);

        final finalConfig = (await discoveryRepo.getConfig()).dataOrNull!;
        final finalCidrs = finalConfig.networkRanges.map((r) => r.cidr).toSet();

        // Neither range is lost
        expect(finalCidrs.contains('10.10.88.0/24'), isTrue);
        expect(finalCidrs.contains('192.168.99.0/24'), isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 16. Baseline multi-factory architecture contracts are upheld
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '16. Baseline multi-factory architecture contracts are upheld',
      () async {
        final factoriesRes = await factoryRepo.getFactories();
        expect(factoriesRes.isSuccess, isTrue);
        final active = factoriesRes.dataOrNull!
            .where((f) => f.isActive)
            .map((f) => f.id)
            .toList();
        expect(active, containsAll(['bnf', 'rnf']));
      },
    );
  });
}
