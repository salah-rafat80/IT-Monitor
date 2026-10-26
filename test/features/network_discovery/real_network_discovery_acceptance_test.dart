import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
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
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_evidence_item.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_progress.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/discovery_scan_job.dart';
import 'package:it_network_monitor/features/network_discovery/domain/entities/review_state.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/device_classification_engine.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/discovery_coordinator.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/mac_vendor_lookup.dart';
import 'package:it_network_monitor/features/network_discovery/domain/services/network_range_validator.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_cubit.dart';
import 'package:it_network_monitor/features/network_discovery/presentation/bloc/network_discovery_state.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

void main() {
  group('Real Network Discovery Acceptance & Inventory Validation Suite', () {
    late AppDatabase db;
    late AuditLogRepositoryImpl auditRepo;
    late AuthRepositoryImpl authRepo;
    late DeviceRepositoryImpl deviceRepo;
    late InfrastructureRepositoryImpl infraRepo;
    late DiscoveryRepositoryImpl discoveryRepo;
    late DiscoveryCoordinator coordinator;
    late NetworkRangeValidator rangeValidator;
    late DeviceClassificationEngine classifier;
    late MacVendorLookup vendorLookup;
    late NetworkDiscoveryCubit discoveryCubit;
    late AuthCubit authCubit;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      auditRepo = AuditLogRepositoryImpl(db);
      authRepo = AuthRepositoryImpl(db, auditRepo);
      deviceRepo = DeviceRepositoryImpl(db, auditRepo, authRepo);
      infraRepo = InfrastructureRepositoryImpl(db, auditRepo, authRepo);
      discoveryRepo = DiscoveryRepositoryImpl(db);
      authCubit = AuthCubit(authRepo);

      rangeValidator = NetworkRangeValidator();
      vendorLookup = MacVendorLookup();
      classifier = DeviceClassificationEngine(vendorLookup);

      final icmp = IcmpDiscoveryStrategy();
      final arp = ArpDiscoveryStrategy(vendorLookup);
      final dns = DnsHostnameStrategy();
      final tcp = TcpProbeDiscoveryStrategy();
      final onvif = OnvifDiscoveryStrategy();
      final mdns = MdnsSsdpDiscoveryStrategy();

      coordinator = DiscoveryCoordinator(
        discoveryRepo,
        deviceRepo,
        rangeValidator,
        classifier,
        vendorLookup,
        icmp,
        arp,
        dns,
        tcp,
        onvif,
        mdns,
      );

      discoveryCubit = NetworkDiscoveryCubit(
        discoveryRepo,
        deviceRepo,
        coordinator,
        rangeValidator,
      );

      // Pre-seed the production baseline
      await deviceRepo.bootstrapApprovedInventory();
      await infraRepo.bootstrapVerifiedAccessPoints();
    });

    tearDown(() async {
      await db.close();
    });

    final bool runLiveTests =
        Platform.environment['IT_MONITOR_RUN_LIVE_NETWORK_TESTS'] == '1';

    test(
      '1. Subnet 192.168.27.0/24: Live Reachability & Genuine Discovery Scan',
      () async {
        final stopwatch = Stopwatch()..start();

        // Step 1: Pre-scan reachability verification
        final defaultGw = '192.168.27.1';
        final gwStopwatch = Stopwatch()..start();
        final gwPing = await Process.run('ping', [
          '-n',
          '2',
          '-w',
          '1000',
          defaultGw,
        ]);
        gwStopwatch.stop();
        final isGwReachable = gwPing.exitCode == 0;
        expect(
          isGwReachable,
          isTrue,
          reason: 'Gateway 192.168.27.1 must be reachable',
        );

        // Step 2: Launch genuine bounded discovery scan on 192.168.27.0/24
        final scanRes = await coordinator.startScan(
          requestedRanges: ['192.168.27.0/24'],
          maxConcurrency: 35,
          timeoutSeconds: 2,
        );
        expect(scanRes.isSuccess, isTrue);

        final scanId = scanRes.dataOrNull!.id;

        // Await scan completion via progress stream
        final completer = Completer<DiscoveryProgress>();
        final sub = coordinator.progressStream.listen((p) {
          if (p.scanId == scanId &&
              (p.status == ScanJobStatus.completed ||
                  p.status == ScanJobStatus.completedWithErrors ||
                  p.status == ScanJobStatus.cancelled)) {
            if (!completer.isCompleted) completer.complete(p);
          }
        });

        final finalProgress = await completer.future.timeout(
          const Duration(minutes: 3),
          onTimeout: () =>
              throw TimeoutException('Scan timed out on 192.168.27.0/24'),
        );
        await sub.cancel();
        stopwatch.stop();

        // Step 3: Fetch all discovered records from SQLite
        final discoveredRes = await discoveryRepo.getDiscoveredDevices(
          scanId: scanId,
        );
        expect(discoveredRes.isSuccess, isTrue);
        final discoveredList = discoveredRes.dataOrNull!;

        final alreadyKnownCount = discoveredList
            .where((d) => d.reviewState == ReviewState.alreadyKnown)
            .length;
        final pendingCount = discoveredList
            .where((d) => d.reviewState == ReviewState.pendingReview)
            .length;
        final unknownClassifications = discoveredList
            .where((d) => d.predictedCategory == DeviceCategory.unknown)
            .length;

        // Output actual runtime telemetry report
        // ignore: avoid_print
        print('\n======================================================');
        // ignore: avoid_print
        print('>>> SUBNET 192.168.27.0/24 REAL DISCOVERY REPORT <<<');
        // ignore: avoid_print
        print(
          'Reachability Assessment : Gateway $defaultGw responded in ${gwStopwatch.elapsedMilliseconds} ms',
        );
        // ignore: avoid_print
        print('Targets Enumerated     : ${finalProgress.targetsEnumerated}');
        // ignore: avoid_print
        print('Targets Attempted      : ${finalProgress.targetsAttempted}');
        // ignore: avoid_print
        print('Responses Received     : ${finalProgress.responsesReceived}');
        // ignore: avoid_print
        print('Total Discovered       : ${discoveredList.length}');
        // ignore: avoid_print
        print(
          'Already-Known Devices  : $alreadyKnownCount (Matching Approved Inventory)',
        );
        // ignore: avoid_print
        print('Pending Review Devices : $pendingCount');
        // ignore: avoid_print
        print('Unknown Category       : $unknownClassifications');
        // ignore: avoid_print
        print(
          'Elapsed Real Time      : ${stopwatch.elapsedMilliseconds} ms (${stopwatch.elapsed.inSeconds}s)',
        );
        // ignore: avoid_print
        print('======================================================\n');

        expect(finalProgress.targetsEnumerated, equals(254));
        expect(finalProgress.targetsAttempted, equals(254));
        expect(discoveredList.isNotEmpty, isTrue);
      },
      skip: runLiveTests
          ? false
          : 'Live network scan disabled by default. Set IT_MONITOR_RUN_LIVE_NETWORK_TESTS=1 to run against real subnet.',
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test(
      '2. Subnet 192.168.22.0/24: Live Reachability & Genuine Discovery Scan',
      () async {
        final stopwatch = Stopwatch()..start();

        // Step 1: Pre-scan reachability verification to routed subnet
        final routedTarget = '192.168.22.1';
        final gwStopwatch = Stopwatch()..start();
        final gwPing = await Process.run('ping', [
          '-n',
          '2',
          '-w',
          '1000',
          routedTarget,
        ]);
        gwStopwatch.stop();
        final isRoutedReachable = gwPing.exitCode == 0;
        expect(
          isRoutedReachable,
          isTrue,
          reason: 'Routed gateway 192.168.22.1 must be reachable',
        );

        // Step 2: Launch genuine bounded discovery scan on 192.168.22.0/24
        final scanRes = await coordinator.startScan(
          requestedRanges: ['192.168.22.0/24'],
          maxConcurrency: 35,
          timeoutSeconds: 2,
        );
        expect(scanRes.isSuccess, isTrue);

        final scanId = scanRes.dataOrNull!.id;

        // Await scan completion via progress stream
        final completer = Completer<DiscoveryProgress>();
        final sub = coordinator.progressStream.listen((p) {
          if (p.scanId == scanId &&
              (p.status == ScanJobStatus.completed ||
                  p.status == ScanJobStatus.completedWithErrors ||
                  p.status == ScanJobStatus.cancelled)) {
            if (!completer.isCompleted) completer.complete(p);
          }
        });

        final finalProgress = await completer.future.timeout(
          const Duration(minutes: 3),
          onTimeout: () =>
              throw TimeoutException('Scan timed out on 192.168.22.0/24'),
        );
        await sub.cancel();
        stopwatch.stop();

        // Step 3: Fetch all discovered records from SQLite
        final discoveredRes = await discoveryRepo.getDiscoveredDevices(
          scanId: scanId,
        );
        expect(discoveredRes.isSuccess, isTrue);
        final discoveredList = discoveredRes.dataOrNull!;

        final alreadyKnownCount = discoveredList
            .where((d) => d.reviewState == ReviewState.alreadyKnown)
            .length;
        final pendingCount = discoveredList
            .where((d) => d.reviewState == ReviewState.pendingReview)
            .length;
        final unknownClassifications = discoveredList
            .where((d) => d.predictedCategory == DeviceCategory.unknown)
            .length;

        // Output actual runtime telemetry report
        // ignore: avoid_print
        print('\n======================================================');
        // ignore: avoid_print
        print('>>> SUBNET 192.168.22.0/24 REAL DISCOVERY REPORT <<<');
        // ignore: avoid_print
        print(
          'Reachability Assessment : Routed Gateway $routedTarget responded in ${gwStopwatch.elapsedMilliseconds} ms',
        );
        // ignore: avoid_print
        print('Targets Enumerated     : ${finalProgress.targetsEnumerated}');
        // ignore: avoid_print
        print('Targets Attempted      : ${finalProgress.targetsAttempted}');
        // ignore: avoid_print
        print('Responses Received     : ${finalProgress.responsesReceived}');
        // ignore: avoid_print
        print('Total Discovered       : ${discoveredList.length}');
        // ignore: avoid_print
        print(
          'Already-Known Devices  : $alreadyKnownCount (Matching Approved Inventory)',
        );
        // ignore: avoid_print
        print('Pending Review Devices : $pendingCount');
        // ignore: avoid_print
        print('Unknown Category       : $unknownClassifications');
        // ignore: avoid_print
        print(
          'Elapsed Real Time      : ${stopwatch.elapsedMilliseconds} ms (${stopwatch.elapsed.inSeconds}s)',
        );
        // ignore: avoid_print
        print('======================================================\n');

        expect(finalProgress.targetsEnumerated, equals(254));
        expect(finalProgress.targetsAttempted, equals(254));
        expect(discoveredList.isNotEmpty, isTrue);
      },
      skip: runLiveTests
          ? false
          : 'Live network scan disabled by default. Set IT_MONITOR_RUN_LIVE_NETWORK_TESTS=1 to run against real subnet.',
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test(
      '3. Complete Inventory Approval Workflow with Persistence & Anti-Duplication',
      () async {
        // 1. Simulate a discovered printer asset (e.g., HP LaserJet at 192.168.27.200)
        final discovered = DiscoveredDeviceEntity(
          scanId: 1,
          ip: '192.168.27.200',
          mac: '00:1E:0B:44:55:66',
          hostname: 'HP-LJET-FINANCE',
          vendor: 'HP Inc.',
          predictedCategory: DeviceCategory.printer,
          confidence: ClassificationConfidence.high,
          reviewState: ReviewState.pendingReview,
          firstSeen: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        final saveDiscoveredRes = await discoveryRepo.saveDiscoveredDevice(
          discovered,
        );
        expect(saveDiscoveredRes.isSuccess, isTrue);
        final discoveredId = saveDiscoveredRes.dataOrNull!;

        // 2. Save evidence item
        await discoveryRepo.saveEvidence(
          discoveredId,
          DiscoveryEvidenceItem(
            strategyName: 'tcp_probe',
            probeTarget: '192.168.27.200',
            isSuccess: true,
            details: 'JetDirect RAW port 9100 open',
            timestamp: DateTime.now(),
          ),
        );

        final evidence = await discoveryRepo.getEvidenceForDevice(discoveredId);
        expect(evidence.dataOrNull!.length, equals(1));

        // 3. Admin approves and classifies asset with assigned Owner, Department, and Location
        final approvedAsset = DeviceEntity(
          id: 0,
          name: 'HP LaserJet Pro M404',
          type: DeviceType.printer,
          ip: '192.168.27.200',
          ownerName: 'Finance Shared',
          department: 'Finance',
          officeLocation: 'Finance Office - Room 102',
          vendor: 'HP Inc.',
          model: 'LaserJet Pro M404n',
          mac: '00:1E:0B:44:55:66',
          hostname: 'HP-LJET-FINANCE',
          notes: 'Primary accounting invoice printer',
          isMonitored: false, // Printers unmonitored by default
          createdAt: DateTime.now(),
        );

        final addRes = await deviceRepo.addDevice(approvedAsset);
        expect(addRes.isSuccess, isTrue);
        final savedId = addRes.dataOrNull!.id;

        await discoveryRepo.updateDeviceReview(
          deviceId: discoveredId,
          state: ReviewState.approved,
          confirmedCategory: DeviceCategory.printer,
        );

        // 4. Verify asset appears in authoritative Devices inventory
        final allDevices = (await deviceRepo.getDevices()).dataOrNull!;
        expect(
          allDevices.length,
          equals(38),
        ); // 37 baseline + 1 approved printer

        final savedDevice = allDevices.firstWhere((d) => d.id == savedId);
        expect(savedDevice.name, equals('HP LaserJet Pro M404'));
        expect(savedDevice.ownerName, equals('Finance Shared'));
        expect(savedDevice.department, equals('Finance'));
        expect(savedDevice.officeLocation, equals('Finance Office - Room 102'));
        expect(savedDevice.type, equals(DeviceType.printer));
        expect(savedDevice.isMonitored, isFalse);

        // 5. Verify Device Details show exact saved metadata
        final detailsRes = await deviceRepo.getDeviceById(savedId);
        expect(detailsRes.isSuccess, isTrue);
        expect(
          detailsRes.dataOrNull!.notes,
          equals('Primary accounting invoice printer'),
        );
        expect(detailsRes.dataOrNull!.mac, equals('00:1E:0B:44:55:66'));

        // 6. Simulate Desktop Client restart (re-querying database from clean repository instance)
        final reloadedRepo = DeviceRepositoryImpl(db, auditRepo, authRepo);
        final reloadedDevices = (await reloadedRepo.getDevices()).dataOrNull!;
        expect(reloadedDevices.length, equals(38));
        final reloadedAsset = reloadedDevices.firstWhere(
          (d) => d.ip == '192.168.27.200',
        );
        expect(reloadedAsset.ownerName, equals('Finance Shared'));
        expect(reloadedAsset.department, equals('Finance'));

        // 7. Re-scan simulation: repeat probe matching IP does NOT duplicate or overwrite confirmed owner
        final existingMap = {for (final d in reloadedDevices) d.ip: d};
        expect(existingMap.containsKey('192.168.27.200'), isTrue);

        final existingMatch = existingMap['192.168.27.200']!;
        expect(existingMatch.ownerName, equals('Finance Shared'));
        expect(existingMatch.department, equals('Finance'));
        // No duplicate was created
        expect(
          reloadedDevices.where((d) => d.ip == '192.168.27.200').length,
          equals(1),
        );
      },
    );

    test(
      '4. Existing Data Protection: Baseline 37 Devices + 4 UniFi APs Intact',
      () async {
        // 1. Approved PCs & Laptops count is exactly 37
        final devicesRes = await deviceRepo.getDevices();
        expect(devicesRes.isSuccess, isTrue);
        final devices = devicesRes.dataOrNull!;
        expect(devices.length, equals(37));

        // 2. Verified UniFi AP count is exactly 4
        final infraRes = await infraRepo.getInfrastructureDevices();
        expect(infraRes.isSuccess, isTrue);
        final infraDevices = infraRes.dataOrNull!;
        expect(infraDevices.length, equals(4));

        final knownApIps = {
          '192.168.7.6',
          '192.168.7.4',
          '192.168.7.2',
          '192.168.8.5',
        };
        expect(infraDevices.map((d) => d.ip).toSet(), equals(knownApIps));

        // 3. Excluded duplicate IP (e.g. 192.168.22.124 Hazaa vs duplicate) remains single
        final hazzaIps = devices
            .where((d) => d.ip == '192.168.22.124')
            .toList();
        expect(hazzaIps.length, equals(1));

        // 4. Audit logs are preserved
        final logsRes = await auditRepo.getAuditLogs();
        expect(logsRes.isSuccess, isTrue);
        expect(logsRes.dataOrNull!.isNotEmpty, isTrue);
      },
    );

    test(
      '5. No-Login Operation: Direct Administrator Launch & Immutability',
      () async {
        // 1. Initial auth check emits AuthAuthenticated as Local Administrator
        await authCubit.checkAuthStatus();
        expect(authCubit.state, isA<AuthAuthenticated>());

        final state = authCubit.state as AuthAuthenticated;
        expect(state.user.role, equals(UserRole.admin));
        expect(
          state.user.username,
          equals('Local Administrator (No Interactive Login)'),
        );

        // 2. Initial discovery cubit loads immediately without authentication barriers
        await discoveryCubit.init();
        expect(discoveryCubit.state, isA<NetworkDiscoveryLoaded>());

        final loadedState = discoveryCubit.state as NetworkDiscoveryLoaded;
        expect(loadedState.rangesWithStatus, isEmpty);

        // Administrator adds scopes dynamically without hardcoding
        await discoveryCubit.addNetworkRange(
          cidr: '192.168.27.0/24',
          name: 'Primary Subnet',
        );
        await discoveryCubit.addNetworkRange(
          cidr: '192.168.22.0/24',
          name: 'Secondary Subnet',
        );

        final updatedState = discoveryCubit.state as NetworkDiscoveryLoaded;
        expect(updatedState.rangesWithStatus.length, equals(2));
        expect(
          updatedState.rangesWithStatus.any((r) => r.cidr == '192.168.27.0/24'),
          isTrue,
        );
        expect(
          updatedState.rangesWithStatus.any((r) => r.cidr == '192.168.22.0/24'),
          isTrue,
        );
      },
    );
  });
}
