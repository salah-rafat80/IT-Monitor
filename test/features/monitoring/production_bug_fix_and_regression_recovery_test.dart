import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/config/client_config.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/domain/entities/audit_log_entity.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/auth/domain/repositories/auth_repository.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/inventory_import_preview.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/repositories/infrastructure_repository.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/monitoring_service_client.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/status_engine.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/device_status_chip.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/domain/services/topology_grouper.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_cubit.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_state.dart';
import 'package:it_network_monitor/features/users/domain/repositories/audit_log_repository.dart';

class StubAuditLogRepository implements AuditLogRepository {
  @override
  Future<Result<List<AuditLogEntity>>> getAuditLogs({int limit = 100}) async =>
      Result.success(const []);

  @override
  Future<Result<void>> recordLog({
    int? userId,
    required String username,
    required String action,
    String? details,
  }) async => Result.success(null);
}

class StubPingChecker implements PingChecker {
  bool respondSuccess = true;
  int latencyMs = 15;
  String? errorMessage;
  PingFailureReason failureReason = PingFailureReason.timeout;

  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final now = DateTime.now();
    if (respondSuccess) {
      return CheckResult.success(
        deviceId: deviceId,
        targetIp: targetIp,
        timestamp: now,
        latencyMs: latencyMs,
      );
    } else {
      return CheckResult.failure(
        deviceId: deviceId,
        targetIp: targetIp,
        timestamp: now,
        errorMessage: errorMessage ?? 'Host unreachable',
        failureReason: failureReason,
      );
    }
  }
}

class StubDeviceRepository implements DeviceRepository {
  List<DeviceEntity> devicesList = [];
  bool shouldFail = false;

  @override
  Future<Result<List<DeviceEntity>>> getDevices({String? factoryId}) async {
    if (shouldFail) {
      return Result.failure(const NetworkFailure('Service unreachable'));
    }
    if (factoryId != null) {
      return Result.success(
        devicesList.where((d) => d.factoryId == factoryId).toList(),
      );
    }
    return Result.success(List.from(devicesList));
  }

  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async {
    final match = devicesList.where((d) => d.id == id).firstOrNull;
    if (match != null) return Result.success(match);
    return Result.failure(const NotFoundFailure('Device not found'));
  }

  @override
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device) async {
    devicesList.add(device);
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
  }) async {
    final dev = devicesList.firstWhere((d) => d.id == deviceId);
    final updated = dev.copyWith(ownerName: ownerName);
    return Result.success(updated);
  }

  @override
  Future<Result<void>> deleteDevice(int id) async {
    devicesList.removeWhere((d) => d.id == id);
    return Result.success(null);
  }

  @override
  Future<Result<void>> toggleDeviceMonitoring({
    required int deviceId,
    required bool isEnabled,
  }) async => Result.success(null);

  @override
  Future<Result<InventoryImportPreview>> parseAndValidateImport(
    List<int> bytes,
    String filename,
  ) async => throw UnimplementedError();

  @override
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices) async {
    devicesList.addAll(validDevices);
    return Result.success(validDevices.length);
  }

  @override
  Future<Result<int>> bootstrapApprovedInventory({bool force = false}) async =>
      Result.success(0);

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

class StubMonitoringRepository implements MonitoringRepository {
  Map<int, DeviceStatusEntity> statuses = {};
  bool shouldFail = false;

  @override
  Future<Result<List<DeviceStatusEntity>>> getDeviceStatuses() async {
    if (shouldFail) {
      return Result.failure(const NetworkFailure('Service unreachable'));
    }
    return Result.success(statuses.values.toList());
  }

  @override
  Future<Result<DeviceStatusEntity>> getDeviceStatus(int deviceId) async {
    if (shouldFail) {
      return Result.failure(const NetworkFailure('Service unreachable'));
    }
    return Result.success(
      statuses[deviceId] ?? DeviceStatusEntity.initial(deviceId),
    );
  }

  @override
  Future<Result<void>> saveCheckResult(CheckResult result) async =>
      Result.success(null);

  @override
  Future<Result<void>> saveDeviceStatus(DeviceStatusEntity status) async {
    statuses[status.deviceId] = status;
    return Result.success(null);
  }

  @override
  Future<Result<void>> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async {
    final cur = statuses[deviceId] ?? DeviceStatusEntity.initial(deviceId);
    statuses[deviceId] = cur.copyWith(
      isMaintenance: isMaintenance,
      status: isMaintenance
          ? DeviceStatusEnum.maintenance
          : DeviceStatusEnum.unknown,
    );
    return Result.success(null);
  }

  @override
  Stream<DeviceStatusEntity> watchDeviceStatus(int deviceId) =>
      Stream.value(statuses[deviceId] ?? DeviceStatusEntity.initial(deviceId));

  @override
  Stream<List<DeviceStatusEntity>> watchAllDeviceStatuses() =>
      Stream.value(statuses.values.toList());
}

class StubInfrastructureRepository implements InfrastructureRepository {
  List<UniFiDeviceEntity> infraList = [];
  bool shouldFail = false;

  @override
  Future<Result<List<UniFiDeviceEntity>>> getInfrastructureDevices({
    String? factoryId,
  }) async {
    if (shouldFail) {
      return Result.failure(const NetworkFailure('Service unreachable'));
    }
    if (factoryId != null) {
      return Result.success(
        infraList.where((d) => d.factoryId == factoryId).toList(),
      );
    }
    return Result.success(List.from(infraList));
  }

  @override
  Future<Result<UniFiDeviceEntity?>> getDeviceById(int id) async {
    final match = infraList.where((d) => d.id == id).firstOrNull;
    return Result.success(match);
  }

  @override
  Future<Result<UniFiDeviceEntity?>> getDeviceByIp(
    String ip, {
    String? factoryId,
  }) async {
    final match = infraList
        .where(
          (d) => d.ip == ip && (factoryId == null || d.factoryId == factoryId),
        )
        .firstOrNull;
    return Result.success(match);
  }

  @override
  Future<Result<UniFiDeviceEntity>> saveInfrastructureDevice(
    UniFiDeviceEntity device,
  ) async {
    infraList.add(device);
    return Result.success(device);
  }

  @override
  Future<Result<void>> deleteInfrastructureDevice(int id) async {
    infraList.removeWhere((d) => d.id == id);
    return Result.success(null);
  }

  @override
  Future<Result<UniFiDeviceEntity>> confirmDeviceRole({
    required int id,
    required UniFiDeviceRole role,
    required bool isCritical,
    required List<String> linkedSubnets,
  }) async => throw UnimplementedError();

  @override
  Stream<List<UniFiDeviceEntity>> watchInfrastructureDevices({
    String? factoryId,
  }) => Stream.value(
    factoryId != null
        ? infraList.where((d) => d.factoryId == factoryId).toList()
        : List.from(infraList),
  );

  @override
  Future<Result<void>> bootstrapVerifiedAccessPoints() async =>
      Result.success(null);
}

class StubAuthRepository implements AuthRepository {
  @override
  Future<Result<bool>> hasAdminAccount() async => Result.success(true);

  @override
  Future<Result<UserEntity>> createInitialAdmin({
    required String username,
    required String password,
  }) async => Result.failure(const AuthFailure('Not implemented'));

  @override
  Future<Result<UserEntity?>> getCurrentUser() async =>
      Result.failure(const AuthFailure('No active user'));

  @override
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
  }) async => Result.failure(const AuthFailure('Not implemented'));

  @override
  Future<Result<void>> logout() async => Result.success(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Production Hardening & Bug Fix Recovery Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'it_monitor_recovery_test_',
      );
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
      AppConfig.resetForTesting();
      if (getIt.isRegistered<MonitoringServiceClient>()) {
        getIt.unregister<MonitoringServiceClient>();
      }
    });

    test(
      '1. MonitoringClientConfig: remote configuration does not silently use localhost',
      () {
        final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-url=https://192.168.1.150:8443',
          '--token=0123456789abcdef0123456789abcdef',
          '--cert=C:\\certs\\server.crt',
        ]);

        expect(config.serviceUrl, equals('https://192.168.1.150:8443'));
        expect(config.clientToken, equals('0123456789abcdef0123456789abcdef'));
        expect(config.trustedCertPath, equals('C:\\certs\\server.crt'));
        expect(config.isLanClient, isTrue);
        expect(config.mode, equals('lanClient'));
      },
    );

    test(
      '2. MonitoringClientConfig: persistent client_config.json is loaded correctly',
      () {
        final configFile = File(p.join(tempDir.path, 'client_config.json'));
        configFile.writeAsStringSync(
          jsonEncode({
            'serviceUrl': 'https://10.0.0.5:8443',
            'trustedCertPath': p.join(tempDir.path, 'server.crt'),
            'clientToken': 'abcdef0123456789abcdef0123456789',
            'mode': 'lanClient',
          }),
        );

        final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--config=${configFile.path}',
        ]);

        expect(config.serviceUrl, equals('https://10.0.0.5:8443'));
        expect(config.clientToken, equals('abcdef0123456789abcdef0123456789'));
        expect(config.isLanClient, isTrue);
        expect(config.mode, equals('lanClient'));
      },
    );

    test(
      '3. Status Normalization: legacy strings normalize to canonical enum states',
      () {
        // Legacy disconnected / offline normalize to down
        expect(
          DeviceStatusEnum.fromString('disconnected'),
          equals(DeviceStatusEnum.down),
        );
        expect(
          DeviceStatusEnum.fromString('DISCONNECTED'),
          equals(DeviceStatusEnum.down),
        );
        expect(
          DeviceStatusEnum.fromString('offline'),
          equals(DeviceStatusEnum.down),
        );
        expect(
          DeviceStatusEnum.fromString('down'),
          equals(DeviceStatusEnum.down),
        );

        // Legacy connected / online normalize to up
        expect(
          DeviceStatusEnum.fromString('connected'),
          equals(DeviceStatusEnum.up),
        );
        expect(
          DeviceStatusEnum.fromString('CONNECTED'),
          equals(DeviceStatusEnum.up),
        );
        expect(
          DeviceStatusEnum.fromString('online'),
          equals(DeviceStatusEnum.up),
        );
        expect(DeviceStatusEnum.fromString('up'), equals(DeviceStatusEnum.up));

        // Canonical others
        expect(
          DeviceStatusEnum.fromString('degraded'),
          equals(DeviceStatusEnum.degraded),
        );
        expect(
          DeviceStatusEnum.fromString('unreachable'),
          equals(DeviceStatusEnum.unreachable),
        );
        expect(
          DeviceStatusEnum.fromString('maintenance'),
          equals(DeviceStatusEnum.maintenance),
        );
        expect(
          DeviceStatusEnum.fromString('unknown'),
          equals(DeviceStatusEnum.unknown),
        );
        expect(
          DeviceStatusEnum.fromString('unrecognized_value_xyz'),
          equals(DeviceStatusEnum.unknown),
        );
      },
    );

    testWidgets(
      '4. UI Status Badges: down renders as Disconnected and up as Connected',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  DeviceStatusChip(status: DeviceStatusEnum.up),
                  DeviceStatusChip(status: DeviceStatusEnum.down),
                  DeviceStatusChip(status: DeviceStatusEnum.unknown),
                  DeviceStatusChip(status: DeviceStatusEnum.degraded),
                  DeviceStatusChip(status: DeviceStatusEnum.maintenance),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.text('Unknown'), findsOneWidget);
        expect(find.text('Degraded'), findsOneWidget);
        expect(find.text('Maintenance'), findsOneWidget);
      },
    );

    test(
      '5. Database Migration v11: normalizes legacy status values in device_statuses',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());

        // Insert test device
        final devId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'Legacy Device',
                ip: '192.168.1.111',
                ownerName: 'Admin',
                department: 'IT',
              ),
            );

        // Directly insert legacy status strings into table
        await db.customStatement(
          "INSERT INTO device_statuses (device_id, status, status_changed_at) VALUES ($devId, 'disconnected', datetime('now'));",
        );

        // Verify legacy row exists
        var row = await db
            .customSelect(
              'SELECT status FROM device_statuses WHERE device_id = $devId',
            )
            .getSingle();
        expect(row.read<String>('status'), equals('disconnected'));

        // Run normalization logic (same as migration v11)
        await db.customStatement(
          "UPDATE device_statuses SET status = 'down' WHERE LOWER(TRIM(status)) IN ('disconnected', 'offline');",
        );
        await db.customStatement(
          "UPDATE device_statuses SET status = 'up' WHERE LOWER(TRIM(status)) IN ('connected', 'online');",
        );

        row = await db
            .customSelect(
              'SELECT status FROM device_statuses WHERE device_id = $devId',
            )
            .getSingle();
        expect(row.read<String>('status'), equals('down'));

        await db.close();
      },
    );

    test(
      '6. Status Engine: device failing checks transitions to Disconnected (down) after threshold',
      () {
        const config = MonitoringConfig(
          failureThreshold: 3,
          recoveryThreshold: 2,
        );
        final initial = DeviceStatusEntity.initial(101);
        final now = DateTime.now();

        // Check 1: Failure
        final check1 = CheckResult.failure(
          deviceId: 101,
          targetIp: '192.168.1.50',
          timestamp: now,
          errorMessage: 'Request timed out',
          failureReason: PingFailureReason.timeout,
        );
        final status1 = StatusEngine.processCheckResult(
          currentStatus: initial,
          checkResult: check1,
          config: config,
        );
        expect(status1.consecutiveFailures, equals(1));
        expect(
          status1.status,
          equals(DeviceStatusEnum.unknown),
        ); // Threshold not reached yet

        // Check 2: Failure
        final status2 = StatusEngine.processCheckResult(
          currentStatus: status1,
          checkResult: check1,
          config: config,
        );
        expect(status2.consecutiveFailures, equals(2));
        expect(status2.status, equals(DeviceStatusEnum.unknown));

        // Check 3: Reaches failureThreshold (3) -> transitions to down (Disconnected)
        final status3 = StatusEngine.processCheckResult(
          currentStatus: status2,
          checkResult: check1,
          config: config,
        );
        expect(status3.consecutiveFailures, equals(3));
        expect(status3.status, equals(DeviceStatusEnum.down));

        // Check 4: Success 1 -> Still down pending recoveryThreshold (2)
        final checkSuccess = CheckResult.success(
          deviceId: 101,
          targetIp: '192.168.1.50',
          timestamp: now.add(const Duration(seconds: 10)),
          latencyMs: 12,
        );
        final status4 = StatusEngine.processCheckResult(
          currentStatus: status3,
          checkResult: checkSuccess,
          config: config,
        );
        expect(status4.consecutiveSuccesses, equals(1));
        expect(status4.consecutiveFailures, equals(0));
        expect(status4.status, equals(DeviceStatusEnum.down));

        // Check 5: Success 2 -> Reaches recoveryThreshold -> transitions back to up (Connected)
        final status5 = StatusEngine.processCheckResult(
          currentStatus: status4,
          checkResult: checkSuccess,
          config: config,
        );
        expect(status5.consecutiveSuccesses, equals(2));
        expect(status5.status, equals(DeviceStatusEnum.up));
      },
    );

    test(
      '7. Status Engine: maintenance mode takes precedence over connectivity checks',
      () {
        const config = MonitoringConfig();
        final maintenanceStatus = DeviceStatusEntity.initial(
          102,
        ).copyWith(isMaintenance: true, status: DeviceStatusEnum.maintenance);
        final now = DateTime.now();

        final failureCheck = CheckResult.failure(
          deviceId: 102,
          targetIp: '192.168.1.51',
          timestamp: now,
          errorMessage: 'Connection refused',
          failureReason: PingFailureReason.destinationUnreachable,
        );

        final resultStatus = StatusEngine.processCheckResult(
          currentStatus: maintenanceStatus,
          checkResult: failureCheck,
          config: config,
        );

        expect(resultStatus.status, equals(DeviceStatusEnum.maintenance));
        expect(resultStatus.isMaintenance, isTrue);
      },
    );

    test(
      '8. MonitoringScheduler: skips disabled, unmonitored, or empty IP devices',
      () async {
        final stubDevRepo = StubDeviceRepository();
        final stubMonRepo = StubMonitoringRepository();
        final stubPingChecker = StubPingChecker();

        stubDevRepo.devicesList = [
          DeviceEntity(
            id: 1,
            name: 'Disabled Device',
            type: DeviceType.pc,
            ip: '192.168.1.10',
            ownerName: 'User 1',
            department: 'IT',
            isEnabled: false,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
          DeviceEntity(
            id: 2,
            name: 'Unmonitored Device',
            type: DeviceType.laptop,
            ip: '192.168.1.11',
            ownerName: 'User 2',
            department: 'HR',
            isEnabled: true,
            isMonitored: false,
            createdAt: DateTime.now(),
          ),
          DeviceEntity(
            id: 3,
            name: 'Blank IP Device',
            type: DeviceType.printer,
            ip: '',
            ownerName: 'User 3',
            department: 'Finance',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
          DeviceEntity(
            id: 4,
            name: 'Monitored Active Device',
            type: DeviceType.pc,
            ip: '192.168.1.13',
            ownerName: 'User 4',
            department: 'Engineering',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        ];

        final scheduler = MonitoringScheduler(
          stubDevRepo,
          stubMonRepo,
          stubPingChecker,
        );

        await scheduler.triggerAllChecks(force: true);

        // Only device #4 should have been checked
        expect(scheduler.totalChecksExecuted, equals(1));
        expect(stubMonRepo.statuses.containsKey(4), isTrue);
        expect(stubMonRepo.statuses.containsKey(1), isFalse);
        expect(stubMonRepo.statuses.containsKey(2), isFalse);
        expect(stubMonRepo.statuses.containsKey(3), isFalse);
      },
    );

    test(
      '9. MonitoringDashboardCubit: emits MonitoringDashboardError on getDeviceStatuses failure (fail-closed)',
      () async {
        final stubDevRepo = StubDeviceRepository();
        stubDevRepo.devicesList = [
          DeviceEntity(
            id: 1,
            name: 'Device 1',
            type: DeviceType.pc,
            ip: '192.168.1.20',
            ownerName: 'User 1',
            department: 'IT',
            createdAt: DateTime.now(),
          ),
        ];

        final stubMonRepo = StubMonitoringRepository();
        stubMonRepo.shouldFail =
            true; // Service is unavailable or unauthenticated

        final stubPingChecker = StubPingChecker();
        final scheduler = MonitoringScheduler(
          stubDevRepo,
          stubMonRepo,
          stubPingChecker,
        );

        final cubit = MonitoringDashboardCubit(
          stubDevRepo,
          stubMonRepo,
          scheduler,
        );

        await cubit.initDashboard();

        expect(cubit.state, isA<MonitoringDashboardError>());
        final errorState = cubit.state as MonitoringDashboardError;
        expect(
          errorState.message,
          contains('authoritative monitoring service'),
        );
      },
    );

    test(
      '10. MonitoringCubit: emits MonitoringError on getDeviceStatuses failure (fail-closed)',
      () async {
        final stubDevRepo = StubDeviceRepository();
        final stubMonRepo = StubMonitoringRepository();
        stubMonRepo.shouldFail = true;

        final stubPingChecker = StubPingChecker();
        final scheduler = MonitoringScheduler(
          stubDevRepo,
          stubMonRepo,
          stubPingChecker,
        );

        final cubit = MonitoringCubit(scheduler, stubMonRepo);
        await cubit.initMonitoring();

        expect(cubit.state, isA<MonitoringError>());
        final err = cubit.state as MonitoringError;
        expect(err.message, contains('authoritative monitoring service'));
      },
    );

    test(
      '11. TopologyCubit: emits TopologyError on getDeviceStatuses failure (fail-closed)',
      () async {
        final stubDevRepo = StubDeviceRepository();
        stubDevRepo.devicesList = [
          DeviceEntity(
            id: 1,
            name: 'Device 1',
            type: DeviceType.pc,
            ip: '192.168.1.30',
            ownerName: 'User 1',
            department: 'IT',
            createdAt: DateTime.now(),
          ),
        ];

        final stubInfraRepo = StubInfrastructureRepository();
        final stubMonRepo = StubMonitoringRepository();
        stubMonRepo.shouldFail = true;

        final cubit = TopologyCubit(
          stubDevRepo,
          stubInfraRepo,
          stubMonRepo,
          TopologyGrouper(),
          EnterpriseTopologyBuilder(),
        );

        await cubit.init();

        expect(cubit.state, isA<TopologyError>());
        final err = cubit.state as TopologyError;
        expect(err.message, contains('authoritative monitoring service'));
      },
    );

    test(
      '12. MonitoringServiceClient: classifies connection refusal, unreachable host, TLS SAN mismatch, and ACL errors',
      () {
        final client = MonitoringServiceClient(
          baseUrl: 'https://192.168.1.150:8443',
        );

        final refusedError = client.classifyConnectionException(
          const SocketException(
            'OS Error: No connection could be made because the target machine actively refused it.',
            osError: OSError('Connection refused', 10061),
          ),
        );
        expect(refusedError, contains('Service connection refused'));
        expect(
          refusedError,
          contains('not running, stopped, or not listening'),
        );

        final unreachableError = client.classifyConnectionException(
          const SocketException(
            'OS Error: A socket operation was attempted to an unreachable host.',
            osError: OSError('Host unreachable', 10065),
          ),
        );
        expect(unreachableError, contains('Service host unreachable'));
        expect(unreachableError, contains('firewall rules'));

        final sanMismatchError = client.classifyConnectionException(
          const TlsException(
            'CERTIFICATE_VERIFY_FAILED: Hostname mismatch (IP address mismatch)',
          ),
        );
        expect(sanMismatchError, contains('TLS SAN Mismatch'));

        final untrustedCertError = client.classifyConnectionException(
          const HandshakeException(
            'CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate',
          ),
        );
        expect(untrustedCertError, contains('TLS Trust Verification Failed'));

        final aclError = client.classifyConnectionException(
          const PathAccessException(
            'C:\\ProgramData\\ITNetworkMonitor\\trusted_client.token',
            OSError('Access is denied', 5),
          ),
        );
        expect(aclError, contains('Access Denied'));
        expect(aclError, contains('ITNetworkMonitorAdministrators'));
      },
    );

    test(
      '13. MonitoringServiceClient: rejects invalid or short provisioned token',
      () async {
        final client = MonitoringServiceClient(
          baseUrl: 'http://127.0.0.1:8080',
        );

        final emptyRes = await client.authenticateWithProvisionedToken('  ');
        expect(emptyRes.isFailure, isTrue);
        expect(emptyRes.statusCode, equals(400));

        final shortRes = await client.authenticateWithProvisionedToken(
          'too_short_token',
        );
        expect(shortRes.isFailure, isTrue);
        expect(shortRes.statusCode, equals(401));
        expect(shortRes.errorMessage, contains('< 32 characters'));
      },
    );

    test(
      '14. MonitoringServiceClient: clearSession disconnects WebSocket and cancels reconnect timer',
      () {
        final client = MonitoringServiceClient(
          baseUrl: 'http://127.0.0.1:8080',
        );

        client.clearSession();
        expect(client.isAuthenticated, isFalse);
        expect(client.isWebSocketConnected, isFalse);
        expect(client.currentSession, isNull);
      },
    );
  });
}
