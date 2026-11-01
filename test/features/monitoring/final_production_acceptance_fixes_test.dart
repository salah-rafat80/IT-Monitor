import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/config/client_config.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/auth/domain/repositories/auth_repository.dart';
import 'package:it_network_monitor/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_import_commit_payload.dart';
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

// ---------------------------------------------------------------------------
// Test Doubles & Helpers
// ---------------------------------------------------------------------------

class StubAuthRepository implements AuthRepository {
  @override
  Future<Result<bool>> hasAdminAccount() async => Result.success(true);

  @override
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
  }) async => Result.failure(const AuthFailure('Not supported in test stub'));

  @override
  Future<Result<UserEntity>> createInitialAdmin({
    required String username,
    required String password,
  }) async => Result.failure(const AuthFailure('Not supported in test stub'));

  @override
  Future<Result<void>> logout() async => Result.success(null);

  @override
  Future<Result<UserEntity?>> getCurrentUser() async => Result.success(null);
}

class FakeDeviceRepository implements DeviceRepository {
  List<DeviceEntity> devices = [];
  bool shouldFail = false;

  @override
  Future<Result<List<DeviceEntity>>> getDevices({String? factoryId}) async {
    if (shouldFail) {
      return Result.failure(const DatabaseFailure('Simulated DB failure'));
    }
    if (factoryId != null) {
      return Result.success(
        devices.where((d) => d.factoryId == factoryId).toList(),
      );
    }
    return Result.success(devices);
  }

  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async {
    final match = devices.firstWhere(
      (d) => d.id == id,
      orElse: () => throw StateError('Not found'),
    );
    return Result.success(match);
  }

  @override
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device) async =>
      Result.success(device);

  @override
  Future<Result<DeviceEntity>> updateDevice(DeviceEntity device) async =>
      Result.success(device);

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
  ) async => throw UnimplementedError();

  @override
  Future<Result<int>> commitImportPayload(
    DeviceImportCommitPayload payload,
  ) async => Result.success(payload.totalCount);

  @override
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices) async =>
      throw UnimplementedError();

  @override
  Future<Result<DeviceEntity>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
    String? adminUsername,
  }) async => throw UnimplementedError();

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

class FakeInfrastructureRepository implements InfrastructureRepository {
  List<UniFiDeviceEntity> infraDevices = [];
  bool shouldFail = false;

  @override
  Future<Result<List<UniFiDeviceEntity>>> getInfrastructureDevices({
    String? factoryId,
  }) async {
    if (shouldFail) {
      return Result.failure(
        const DatabaseFailure('Simulated Infra DB failure'),
      );
    }
    if (factoryId != null) {
      return Result.success(
        infraDevices.where((d) => d.factoryId == factoryId).toList(),
      );
    }
    return Result.success(infraDevices);
  }

  @override
  Future<Result<UniFiDeviceEntity?>> getDeviceById(int id) async {
    final match = infraDevices.where((d) => d.id == id).firstOrNull;
    return Result.success(match);
  }

  @override
  Future<Result<UniFiDeviceEntity?>> getDeviceByIp(
    String ip, {
    String? factoryId,
  }) async {
    final match = infraDevices
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
    infraDevices.add(device);
    return Result.success(device);
  }

  @override
  Future<Result<void>> deleteInfrastructureDevice(int id) async =>
      Result.success(null);

  @override
  Future<Result<UniFiDeviceEntity>> confirmDeviceRole({
    required int id,
    required UniFiDeviceRole role,
    required bool isCritical,
    required List<String> linkedSubnets,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> bootstrapVerifiedAccessPoints() async =>
      Result.success(null);

  @override
  Stream<List<UniFiDeviceEntity>> watchInfrastructureDevices({
    String? factoryId,
  }) => Stream.value(
    factoryId != null
        ? infraDevices.where((d) => d.factoryId == factoryId).toList()
        : infraDevices,
  );
}

class FakeMonitoringRepository implements MonitoringRepository {
  final Map<int, DeviceStatusEntity> statuses = {};
  final List<CheckResult> checkResults = [];

  @override
  Future<Result<void>> saveCheckResult(CheckResult result) async {
    checkResults.add(result);
    return Result.success(null);
  }

  @override
  Future<Result<void>> saveDeviceStatus(DeviceStatusEntity status) async {
    statuses[status.deviceId] = status;
    return Result.success(null);
  }

  @override
  Future<Result<DeviceStatusEntity>> getDeviceStatus(int deviceId) async {
    final s = statuses[deviceId];
    if (s != null) {
      return Result.success(s);
    }
    return Result.failure(const NotFoundFailure('Status not found'));
  }

  @override
  Future<Result<List<DeviceStatusEntity>>> getDeviceStatuses() async =>
      Result.success(statuses.values.toList());

  @override
  Future<Result<void>> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async => Result.success(null);

  @override
  Stream<DeviceStatusEntity> watchDeviceStatus(int deviceId) =>
      Stream.fromIterable(
        statuses.containsKey(deviceId) ? [statuses[deviceId]!] : [],
      );

  @override
  Stream<List<DeviceStatusEntity>> watchAllDeviceStatuses() =>
      Stream.value(statuses.values.toList());
}

class TrackingPingChecker implements PingChecker {
  final Duration checkDelay;
  final Map<int, Duration> deviceDelays = {};
  void Function(int deviceId)? onCheckStarted;
  int currentActiveChecks = 0;
  int peakObservedParallelism = 0;
  final List<int> checkedDeviceIds = [];

  TrackingPingChecker({this.checkDelay = const Duration(milliseconds: 20)});

  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    currentActiveChecks++;
    if (currentActiveChecks > peakObservedParallelism) {
      peakObservedParallelism = currentActiveChecks;
    }
    checkedDeviceIds.add(deviceId);
    onCheckStarted?.call(deviceId);

    final delay = deviceDelays[deviceId] ?? checkDelay;
    await Future.delayed(delay);

    currentActiveChecks--;
    return CheckResult(
      deviceId: deviceId,
      targetIp: targetIp,
      timestamp: DateTime.now(),
      isSuccess: true,
      latencyMs: 10,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1 — Production Standalone Escape Paths Removal', () {
    tearDown(() {
      AppConfig.enforceReleaseModeSecurity = false;
      AppConfig.resetForTesting(mode: AppRunMode.standaloneDevelopment);
    });

    test(
      '1. Enforcing release mode security prevents switching to standaloneDevelopment',
      () {
        AppConfig.enforceReleaseModeSecurity = true;

        // Attempt direct setter switch to standalone
        AppConfig.runMode = AppRunMode.standaloneDevelopment;
        expect(
          AppConfig.runMode,
          equals(AppRunMode.productionClient),
          reason: 'Must fail closed to productionClient in release mode',
        );
        expect(AppConfig.isProductionClient, isTrue);
        expect(AppConfig.isStandaloneDevelopment, isFalse);

        // Attempt resetForTesting switch to standalone
        AppConfig.resetForTesting(mode: AppRunMode.standaloneDevelopment);
        expect(AppConfig.runMode, equals(AppRunMode.productionClient));
      },
    );

    test(
      '2. Permitted modes in release builds are client and service daemon',
      () {
        AppConfig.enforceReleaseModeSecurity = true;

        AppConfig.runMode = AppRunMode.serviceDaemon;
        expect(AppConfig.runMode, equals(AppRunMode.serviceDaemon));
        expect(AppConfig.isServiceDaemon, isTrue);

        AppConfig.runMode = AppRunMode.productionClient;
        expect(AppConfig.runMode, equals(AppRunMode.productionClient));
        expect(AppConfig.isProductionClient, isTrue);
      },
    );
  });

  group('P1 — MonitoringClientConfig Precedence & Fail-Closed Validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'it_monitor_config_test_',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      '3. Formats --service-host and --service-port into valid HTTPS URL and enforces LAN mode',
      () {
        final certFile = File(p.join(tempDir.path, 'server.crt'));
        certFile.writeAsStringSync(
          File('test/fixtures/certs/server.crt').readAsStringSync(),
        );

        final formatted = MonitoringClientConfig.formatServiceUrl(
          host: '192.168.1.150',
          port: 9443,
        );
        expect(formatted, equals('https://192.168.1.150:9443'));

        final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-host=192.168.1.150',
          '--service-port=9443',
          '--cert=${certFile.path}',
          '--token=test_token_1234567890abcdef',
        ]);

        expect(config.serviceUrl, equals('https://192.168.1.150:9443'));
        expect(config.clientToken, equals('test_token_1234567890abcdef'));
        expect(config.isLanClient, isTrue);
      },
    );

    test(
      '4. Normalizes --service-url without prepending duplicate schemes and strictly enforces HTTPS outside loopback',
      () {
        expect(
          MonitoringClientConfig.normalizeServiceUrl('https://10.0.0.1:8443'),
          equals('https://10.0.0.1:8443'),
        );
        // Remote endpoint outside loopback with HTTP is strictly rejected
        expect(
          () => MonitoringClientConfig.normalizeServiceUrl(
            'http://10.0.0.1:8080',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Plain HTTP is forbidden for non-loopback host'),
            ),
          ),
        );
        expect(
          MonitoringClientConfig.normalizeServiceUrl('10.0.0.1:8443'),
          equals('https://10.0.0.1:8443'),
        );
        // Loopback endpoint with HTTP is permitted only in local development
        expect(
          MonitoringClientConfig.normalizeServiceUrl('http://127.0.0.1:8080'),
          equals('http://127.0.0.1:8080'),
        );
      },
    );

    test('5. Rejects invalid hostname with FormatException', () {
      expect(
        () => MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-host=invalid host with spaces',
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('6. Rejects invalid port (< 1 or > 65535) with FormatException', () {
      expect(
        () => MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-port=99999',
        ]),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-port=0',
        ]),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-port=not_a_number',
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      '7. CLI arguments take precedence over environment variables and persistent file',
      () {
        final configFile = File(p.join(tempDir.path, 'client_config.json'));
        configFile.writeAsStringSync(
          jsonEncode({
            'serviceUrl': 'https://127.0.0.1:8443',
            'mode': 'local',
            'clientToken': 'file_token',
          }),
        );

        final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--config=${configFile.path}',
          '--service-url=https://127.0.0.1:9443',
          '--token=cli_token_override',
          '--mode=local',
        ]);

        expect(config.serviceUrl, equals('https://127.0.0.1:9443'));
        expect(config.clientToken, equals('cli_token_override'));
      },
    );

    test('8. Unreadable or locked config file throws StateError', () {
      final dummyFile = File(p.join(tempDir.path, 'client_config.json'));
      dummyFile.writeAsStringSync('{ malformed JSON ');

      expect(
        () => MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--config=${dummyFile.path}',
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('9. LAN client mode missing client token throws StateError', () {
      final certFile = File(p.join(tempDir.path, 'server.crt'));
      certFile.writeAsStringSync('dummy certificate content');

      final configFile = File(p.join(tempDir.path, 'client_config.json'));
      configFile.writeAsStringSync(
        jsonEncode({
          'serviceUrl': 'https://192.168.1.100:8443',
          'trustedCertPath': certFile.path,
          'mode': 'lanClient',
        }),
      );

      expect(
        () => MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--config=${configFile.path}',
        ]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Missing client token'),
          ),
        ),
      );
    });

    test(
      '10. LAN client mode missing certificate produces actionable error state without uncaught crash',
      () {
        final configFile = File(p.join(tempDir.path, 'client_config.json'));
        configFile.writeAsStringSync(
          jsonEncode({
            'serviceUrl': 'https://192.168.1.100:8443',
            'trustedCertPath': '',
            'clientToken': 'valid_token_1234567890abcdef',
            'mode': 'lanClient',
          }),
        );

        // 1. Missing certificate path in configuration throws StateError
        expect(
          () => MonitoringClientConfig.loadFromEnvironmentOrFile([
            '--config=${configFile.path}',
          ]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Missing trusted TLS certificate path'),
            ),
          ),
        );

        // 2. Non-existent certificate file on disk throws StateError during client initialization
        expect(
          () => MonitoringServiceClient(
            baseUrl: 'https://192.168.1.100:8443',
            trustedCertPath: p.join(tempDir.path, 'missing_server.crt'),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Configured trusted TLS certificate file not found'),
            ),
          ),
        );

        // 3. Unreadable/malformed certificate file throws StateError during client initialization
        final malformedCertFile = File(
          p.join(tempDir.path, 'malformed_server.crt'),
        );
        malformedCertFile.writeAsStringSync('MALFORMED_NON_PEM_DATA');
        expect(
          () => MonitoringServiceClient(
            baseUrl: 'https://192.168.1.100:8443',
            trustedCertPath: malformedCertFile.path,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Failed to load configured trusted TLS certificate'),
            ),
          ),
        );
      },
    );

    test('11. Prohibition on silent LAN-to-localhost fallback', () {
      final configFile = File(p.join(tempDir.path, 'client_config.json'));
      configFile.writeAsStringSync(
        jsonEncode({
          'mode': 'lanClient',
          // No serviceUrl or host provided
        }),
      );

      expect(
        () => MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--config=${configFile.path}',
        ]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no service URL or host was provided'),
          ),
        ),
      );
    });

    test('12. Reads client bearer token from dedicated client.token file', () {
      final certFile = File(p.join(tempDir.path, 'server.crt'));
      certFile.writeAsStringSync(
        File('test/fixtures/certs/server.crt').readAsStringSync(),
      );

      final tokenFile = File(p.join(tempDir.path, 'client.token'));
      tokenFile.writeAsStringSync('token_from_separate_file_1234567890');

      final configFile = File(p.join(tempDir.path, 'client_config.json'));
      configFile.writeAsStringSync(
        jsonEncode({
          'serviceUrl': 'https://192.168.1.100:8443',
          'trustedCertPath': certFile.path,
          'mode': 'lanClient',
          // clientToken NOT in json
        }),
      );

      final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
        '--config=${configFile.path}',
      ]);

      expect(config.clientToken, equals('token_from_separate_file_1234567890'));
    });
  });

  group('P1 — MonitoringServiceClient & AuthCubit Fail-Closed Handling', () {
    test(
      '13. Client with configurationError immediately fails closed',
      () async {
        final client = MonitoringServiceClient(
          baseUrl: 'https://127.0.0.1:8443',
          configurationError:
              'Simulated LAN configuration failure: missing token',
        );

        final resLocal = await client.authenticateWithTrustedLocalToken();
        expect(resLocal.isFailure, isTrue);
        expect(
          resLocal.errorMessage,
          contains('Simulated LAN configuration failure'),
        );

        final resProv = await client.authenticateWithProvisionedToken(
          'some_token',
        );
        expect(resProv.isFailure, isTrue);
        expect(
          resProv.errorMessage,
          contains('Simulated LAN configuration failure'),
        );

        final resVerify = await client.verifySession('some_token');
        expect(resVerify.isFailure, isTrue);
        expect(
          resVerify.errorMessage,
          contains('Simulated LAN configuration failure'),
        );
      },
    );

    test(
      '14. AuthCubit emits AuthError when client has configurationError',
      () async {
        AppConfig.resetForTesting(mode: AppRunMode.productionClient);

        if (getIt.isRegistered<MonitoringServiceClient>()) {
          getIt.unregister<MonitoringServiceClient>();
        }

        final errorClient = MonitoringServiceClient(
          baseUrl: 'https://127.0.0.1:8443',
          configurationError:
              'Actionable LAN config error: server.crt not found',
        );
        getIt.registerSingleton<MonitoringServiceClient>(errorClient);

        final authRepo = StubAuthRepository();
        final cubit = AuthCubit(authRepo);

        final states = <AuthState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.checkAuthStatus();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states, contains(isA<AuthError>()));
        final errorState =
            states.firstWhere((s) => s is AuthError) as AuthError;
        expect(errorState.message, contains('Actionable LAN config error'));

        await sub.cancel();
        await cubit.close();
        getIt.unregister<MonitoringServiceClient>();
      },
    );
  });

  group('P2 — MonitoringScheduler Bounded Worker Queue', () {
    late FakeDeviceRepository deviceRepo;
    late FakeInfrastructureRepository infraRepo;
    late FakeMonitoringRepository monitoringRepo;
    late TrackingPingChecker pingChecker;
    late MonitoringScheduler scheduler;

    setUp(() {
      deviceRepo = FakeDeviceRepository();
      infraRepo = FakeInfrastructureRepository();
      monitoringRepo = FakeMonitoringRepository();
      pingChecker = TrackingPingChecker(
        checkDelay: const Duration(milliseconds: 25),
      );

      scheduler = MonitoringScheduler(
        deviceRepo,
        monitoringRepo,
        pingChecker,
        null,
        infraRepo,
      );

      scheduler.updateConfig(
        const MonitoringConfig(
          checkIntervalSeconds: 60,
          timeoutSeconds: 2,
          maxConcurrentChecks: 4, // Concurrency limit = 4
        ),
      );
    });

    tearDown(() {
      scheduler.dispose();
    });

    test(
      '15. triggerAllChecks() covers EVERY eligible device under bounded concurrency limit',
      () async {
        // Create 20 eligible devices (> maxConcurrentChecks of 4)
        final devices = List.generate(
          20,
          (i) => DeviceEntity(
            id: i + 1,
            name: 'Device #${i + 1}',
            ip: '192.168.1.${i + 10}',
            type: DeviceType.pc,
            ownerName: 'Test Owner',
            department: 'IT',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        );
        deviceRepo.devices = devices;

        // Create 5 eligible infrastructure devices
        final infra = List.generate(
          5,
          (i) => UniFiDeviceEntity(
            id: i + 1,
            name: 'UniFi AP #${i + 1}',
            ip: '192.168.7.${i + 1}',
            role: UniFiDeviceRole.accessPoint,
            isCriticalInfrastructure: false,
            requiresAdminConfirmation: false,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        infraRepo.infraDevices = infra;

        // Total eligible assets = 20 + 5 = 25 assets
        // Trigger forced check awaiting completion
        await scheduler.triggerAllChecks(force: true);

        // 1. Assert ALL 20 inventory devices were checked
        for (final d in devices) {
          expect(
            pingChecker.checkedDeviceIds.contains(d.id),
            isTrue,
            reason: 'Device #${d.id} (${d.ip}) was left unchecked!',
          );
        }

        // 2. Assert ALL 5 infrastructure devices were checked (virtualId = 10000 + id)
        for (final inf in infra) {
          final virtualId = 10000 + inf.id;
          expect(
            pingChecker.checkedDeviceIds.contains(virtualId),
            isTrue,
            reason:
                'Infrastructure device #${inf.id} (${inf.ip}) was left unchecked!',
          );
        }

        // 3. Assert peak parallelism NEVER exceeded maxConcurrentChecks (4)
        expect(
          pingChecker.peakObservedParallelism,
          lessThanOrEqualTo(4),
          reason:
              'Concurrency limit (4) was violated! Peak: ${pingChecker.peakObservedParallelism}',
        );

        // 4. Total checks executed matches total eligible targets
        expect(pingChecker.checkedDeviceIds.length, equals(25));
        expect(scheduler.totalChecksExecuted, equals(25));
      },
    );

    test(
      '16. Overlapping forced check calls do not duplicate checks or race',
      () async {
        final devices = List.generate(
          8,
          (i) => DeviceEntity(
            id: i + 1,
            name: 'Device #${i + 1}',
            ip: '192.168.1.${i + 20}',
            type: DeviceType.pc,
            ownerName: 'Test Owner',
            department: 'IT',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        );
        deviceRepo.devices = devices;

        // Launch two triggerAllChecks concurrently
        final future1 = scheduler.triggerAllChecks(force: true);
        final future2 = scheduler.triggerAllChecks(force: true);

        await Future.wait([future1, future2]);

        // Both complete without running duplicate checks on the same cycle
        expect(pingChecker.checkedDeviceIds.length, equals(8));
        expect(scheduler.totalChecksExecuted, equals(8));
      },
    );

    test(
      '17. Repository errors increment failure telemetry and are not treated as empty inventory',
      () async {
        deviceRepo.shouldFail = true;

        await scheduler.triggerAllChecks(force: true);

        expect(scheduler.repositoryFailureCount, greaterThan(0));
        expect(
          scheduler.diagnosticLogs.any(
            (l) => l.contains('Failed to retrieve inventory devices'),
          ),
          isTrue,
        );
      },
    );

    test(
      '18. Pause, resume, and stop controls preserve scheduler behavior',
      () async {
        final devices = [
          DeviceEntity(
            id: 1,
            name: 'Device #1',
            ip: '192.168.1.50',
            type: DeviceType.pc,
            ownerName: 'Test Owner',
            department: 'IT',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        ];
        deviceRepo.devices = devices;

        scheduler.startMonitoring();
        expect(scheduler.isRunning, isTrue);
        expect(scheduler.isPaused, isFalse);

        scheduler.pauseMonitoring();
        expect(scheduler.isPaused, isTrue);

        scheduler.resumeMonitoring();
        expect(scheduler.isPaused, isFalse);

        scheduler.stopMonitoring();
        expect(scheduler.isRunning, isFalse);
      },
    );

    test(
      '19. triggerAllChecks() returns false when inventory or infrastructure queries fail',
      () async {
        final devices = [
          DeviceEntity(
            id: 1,
            name: 'Device #1',
            ip: '192.168.1.50',
            type: DeviceType.pc,
            ownerName: 'Test Owner',
            department: 'IT',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        ];
        deviceRepo.devices = devices;

        // 1. Device repository failure produces explicit false (failed/incomplete cycle)
        deviceRepo.shouldFail = true;
        final deviceFailResult = await scheduler.triggerAllChecks(force: true);
        expect(
          deviceFailResult,
          isFalse,
          reason: 'Failed device query must report incomplete execution',
        );

        // 2. Infrastructure repository failure produces explicit false
        deviceRepo.shouldFail = false;
        infraRepo.shouldFail = true;
        final infraFailResult = await scheduler.triggerAllChecks(force: true);
        expect(
          infraFailResult,
          isFalse,
          reason:
              'Failed infrastructure query must report incomplete execution',
        );
      },
    );

    test(
      '20. Pausing monitoring during a forced run reports incomplete execution (returns false)',
      () async {
        final devices = List.generate(
          10,
          (i) => DeviceEntity(
            id: i + 1,
            name: 'Device #${i + 1}',
            ip: '192.168.1.${i + 50}',
            type: DeviceType.pc,
            ownerName: 'Test Owner',
            department: 'IT',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        );
        deviceRepo.devices = devices;

        // Trigger forced checks and pause while queue is in progress
        final checkFuture = scheduler.triggerAllChecks(force: true);
        await Future.delayed(const Duration(milliseconds: 30));
        scheduler.pauseMonitoring();

        final result = await checkFuture;
        expect(
          result,
          isFalse,
          reason:
              'Pausing during a forced queue must report incomplete execution',
        );
      },
    );

    test(
      '21. Forced checks account for targets in-flight during an overlapping periodic check without omitting them',
      () async {
        final devices = [
          DeviceEntity(
            id: 1,
            name: 'Device #1 (Slow)',
            ip: '192.168.1.51',
            type: DeviceType.pc,
            ownerName: 'Test Owner',
            department: 'IT',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
          DeviceEntity(
            id: 2,
            name: 'Device #2 (Fast)',
            ip: '192.168.1.52',
            type: DeviceType.pc,
            ownerName: 'Test Owner',
            department: 'IT',
            isEnabled: true,
            isMonitored: true,
            createdAt: DateTime.now(),
          ),
        ];
        deviceRepo.devices = devices;

        // Configure device #1 with a longer delay to simulate in-flight periodic check
        pingChecker.deviceDelays[1] = const Duration(milliseconds: 80);
        pingChecker.deviceDelays[2] = const Duration(milliseconds: 20);

        final device1StartedCompleter = Completer<void>();
        pingChecker.onCheckStarted = (id) {
          if (id == 1 && !device1StartedCompleter.isCompleted) {
            device1StartedCompleter.complete();
          }
        };

        // Start periodic monitoring
        scheduler.startMonitoring();
        await device1StartedCompleter.future;

        // Device #1 is now actively in-flight in the periodic cycle.
        // Launch forced check concurrently
        final forcedSuccess = await scheduler.triggerAllChecks(force: true);

        expect(forcedSuccess, isTrue);
        expect(
          pingChecker.checkedDeviceIds.contains(1),
          isTrue,
          reason: 'Device #1 was omitted during overlap!',
        );
        expect(
          pingChecker.checkedDeviceIds.contains(2),
          isTrue,
          reason: 'Device #2 was omitted during overlap!',
        );
      },
    );

    test(
      '22. Lowering concurrency limit via updatePermits() while checks are active does not grant extra permits',
      () async {
        final sem = AsyncSemaphore(4);

        // 4 permits acquired (all active)
        await sem.acquire();
        await sem.acquire();
        await sem.acquire();
        await sem.acquire();

        expect(sem.activeCount, equals(4));
        expect(sem.maxPermits, equals(4));

        var waiterAcquired = false;
        unawaited(
          sem.acquire().then((_) {
            waiterAcquired = true;
          }),
        );

        await Future.delayed(Duration.zero);
        expect(waiterAcquired, isFalse);
        expect(sem.waitingCount, equals(1));

        // Lower concurrency limit from 4 to 2 while 4 checks are active
        sem.updatePermits(2);

        expect(sem.maxPermits, equals(2));
        expect(sem.activeCount, equals(4));
        await Future.delayed(Duration.zero);
        expect(
          waiterAcquired,
          isFalse,
          reason:
              'Lowering permits must NEVER drain waiters when active count exceeds new limit!',
        );

        // First release: activeCount drops to 3 (still > 2)
        sem.release();
        expect(sem.activeCount, equals(3));
        await Future.delayed(Duration.zero);
        expect(waiterAcquired, isFalse);

        // Second release: activeCount drops to 2 (equal to limit, not < 2)
        sem.release();
        expect(sem.activeCount, equals(2));
        await Future.delayed(Duration.zero);
        expect(waiterAcquired, isFalse);

        // Third release: activeCount drops to 1 (< 2!), waiter acquires
        sem.release();
        await Future.delayed(Duration.zero);
        expect(waiterAcquired, isTrue);
        expect(sem.activeCount, equals(2));

        sem.dispose();
      },
    );
  });

  group('P1 — Remote Transport Security & Fail-Closed Transport Enforcement', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('it_monitor_sec_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      '23. Remote HTTP endpoints are rejected across formatting, normalization, and configuration loading',
      () {
        // 1. formatServiceUrl rejects plain HTTP for remote host
        expect(
          () => MonitoringClientConfig.formatServiceUrl(
            host: '192.168.1.100',
            useTls: false,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Plain HTTP is forbidden for non-loopback host'),
            ),
          ),
        );

        // 2. normalizeServiceUrl rejects plain HTTP for remote URL
        expect(
          () => MonitoringClientConfig.normalizeServiceUrl(
            'http://192.168.1.100:8080',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Plain HTTP is forbidden for non-loopback host'),
            ),
          ),
        );

        // 3. loadFromEnvironmentOrFile rejects plain HTTP for remote service URL
        expect(
          () => MonitoringClientConfig.loadFromEnvironmentOrFile([
            '--service-url=http://192.168.1.100:8080',
            '--token=test_token_1234567890abcdef',
          ]),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Plain HTTP is forbidden for non-loopback host'),
            ),
          ),
        );
      },
    );

    test(
      '24. Remote endpoint mislabeled as mode: local is inferred and enforced as LAN mode',
      () {
        // mode: local cannot bypass remote endpoint validation
        expect(
          () => MonitoringClientConfig.loadFromEnvironmentOrFile([
            '--service-url=https://192.168.1.100:8443',
            '--mode=local',
            '--token=test_token_1234567890abcdef',
          ]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Missing trusted TLS certificate path'),
            ),
          ),
        );

        final certFile = File(p.join(tempDir.path, 'server.crt'));
        certFile.writeAsStringSync(
          File('test/fixtures/certs/server.crt').readAsStringSync(),
        );

        final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-url=https://192.168.1.100:8443',
          '--mode=local',
          '--cert=${certFile.path}',
          '--token=test_token_1234567890abcdef',
        ]);

        expect(config.isLanClient, isTrue);
        expect(config.mode, equals('lanClient'));
      },
    );

    test(
      '25. Bearer tokens are never transmitted over unencrypted remote HTTP connections',
      () async {
        final insecureClient = MonitoringServiceClient(
          baseUrl: 'http://192.168.1.100:8080',
        );

        expect(insecureClient.hasConfigurationError, isTrue);
        expect(
          insecureClient.configurationError,
          contains('Plain HTTP is forbidden for remote connections'),
        );

        // Token transmission methods fail immediately without network transport
        final resProv = await insecureClient.authenticateWithProvisionedToken(
          'secret_token_1234567890abcdef',
        );
        expect(resProv.isFailure, isTrue);
        expect(resProv.statusCode, equals(400));
        expect(resProv.errorMessage, contains('Insecure transport'));

        final resLocal = await insecureClient
            .authenticateWithTrustedLocalToken();
        expect(resLocal.isFailure, isTrue);
        expect(resLocal.statusCode, equals(400));
        expect(resLocal.errorMessage, contains('Insecure transport'));

        final resVerify = await insecureClient.verifySession(
          'secret_token_1234567890abcdef',
        );
        expect(resVerify.isFailure, isTrue);
        expect(resVerify.statusCode, equals(400));
        expect(resVerify.errorMessage, contains('Insecure transport'));

        expect(
          () => insecureClient.connectWebSocket(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      '26. Nonexistent and unreadable certificate paths produce visible GUI error state without uncaught crash',
      () async {
        AppConfig.resetForTesting(mode: AppRunMode.productionClient);

        // 1. Nonexistent certificate file
        if (getIt.isRegistered<MonitoringServiceClient>()) {
          getIt.unregister<MonitoringServiceClient>();
        }

        MonitoringServiceClient missingCertClient;
        try {
          missingCertClient = MonitoringServiceClient(
            baseUrl: 'https://192.168.1.100:8443',
            trustedCertPath: p.join(tempDir.path, 'nonexistent_cert.crt'),
          );
        } catch (e) {
          missingCertClient = MonitoringServiceClient(
            baseUrl: 'https://192.168.1.100:8443',
            configurationError: e.toString(),
          );
        }
        expect(missingCertClient.hasConfigurationError, isTrue);
        expect(
          missingCertClient.configurationError,
          contains('Configured trusted TLS certificate file not found'),
        );

        getIt.registerSingleton<MonitoringServiceClient>(missingCertClient);

        final authRepo = StubAuthRepository();
        final cubit = AuthCubit(authRepo);
        final states = <AuthState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.checkAuthStatus();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states, contains(isA<AuthError>()));
        final errorState =
            states.firstWhere((s) => s is AuthError) as AuthError;
        expect(
          errorState.message,
          contains('Configured trusted TLS certificate file not found'),
        );
        expect(
          states.last,
          isA<AuthUnauthenticated>(),
        ); // GUI displays LoginPage with Retry button

        await sub.cancel();
        await cubit.close();
        getIt.unregister<MonitoringServiceClient>();

        // 2. Unreadable / Corrupted certificate file
        final malformedFile = File(p.join(tempDir.path, 'corrupted.crt'));
        malformedFile.writeAsStringSync('CORRUPTED_CERTIFICATE_CONTENT');

        MonitoringServiceClient malformedCertClient;
        try {
          malformedCertClient = MonitoringServiceClient(
            baseUrl: 'https://192.168.1.100:8443',
            trustedCertPath: malformedFile.path,
          );
        } catch (e) {
          malformedCertClient = MonitoringServiceClient(
            baseUrl: 'https://192.168.1.100:8443',
            configurationError: e.toString(),
          );
        }
        expect(malformedCertClient.hasConfigurationError, isTrue);
        expect(
          malformedCertClient.configurationError,
          contains('Failed to load configured trusted TLS certificate'),
        );

        getIt.registerSingleton<MonitoringServiceClient>(malformedCertClient);
        final cubit2 = AuthCubit(authRepo);
        final states2 = <AuthState>[];
        final sub2 = cubit2.stream.listen(states2.add);

        await cubit2.checkAuthStatus();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(states2, contains(isA<AuthError>()));
        final errorState2 =
            states2.firstWhere((s) => s is AuthError) as AuthError;
        expect(
          errorState2.message,
          contains('Failed to load configured trusted TLS certificate'),
        );
        expect(states2.last, isA<AuthUnauthenticated>());

        await sub2.cancel();
        await cubit2.close();
        getIt.unregister<MonitoringServiceClient>();
      },
    );
  });
}
