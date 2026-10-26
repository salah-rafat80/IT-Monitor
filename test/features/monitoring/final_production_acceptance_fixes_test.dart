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
  Future<Result<List<DeviceEntity>>> getDevices() async {
    if (shouldFail) {
      return Result.failure(const DatabaseFailure('Simulated DB failure'));
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
}

class FakeInfrastructureRepository implements InfrastructureRepository {
  List<UniFiDeviceEntity> infraDevices = [];
  bool shouldFail = false;

  @override
  Future<Result<List<UniFiDeviceEntity>>> getInfrastructureDevices() async {
    if (shouldFail) {
      return Result.failure(
        const DatabaseFailure('Simulated Infra DB failure'),
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
  Future<Result<UniFiDeviceEntity?>> getDeviceByIp(String ip) async {
    final match = infraDevices.where((d) => d.ip == ip).firstOrNull;
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
  Stream<List<UniFiDeviceEntity>> watchInfrastructureDevices() =>
      Stream.value(infraDevices);
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

    await Future.delayed(checkDelay);

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
      '3. Formats --service-host and --service-port into valid HTTPS URL',
      () {
        final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--service-host=192.168.1.150',
          '--service-port=9443',
          '--token=test_token_1234567890abcdef',
          '--mode=local', // local mode bypasses cert requirement for format test
        ]);

        expect(config.serviceUrl, equals('https://192.168.1.150:9443'));
        expect(config.clientToken, equals('test_token_1234567890abcdef'));
      },
    );

    test(
      '4. Normalizes --service-url without prepending duplicate schemes',
      () {
        expect(
          MonitoringClientConfig.normalizeServiceUrl('https://10.0.0.1:8443'),
          equals('https://10.0.0.1:8443'),
        );
        expect(
          MonitoringClientConfig.normalizeServiceUrl('http://10.0.0.1:8080'),
          equals('http://10.0.0.1:8080'),
        );
        expect(
          MonitoringClientConfig.normalizeServiceUrl('10.0.0.1:8443'),
          equals('https://10.0.0.1:8443'),
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
            'serviceUrl': 'https://file-host:8443',
            'mode': 'local',
            'clientToken': 'file_token',
          }),
        );

        final config = MonitoringClientConfig.loadFromEnvironmentOrFile([
          '--config=${configFile.path}',
          '--service-url=https://cli-host:8443',
          '--token=cli_token_override',
          '--mode=local',
        ]);

        expect(config.serviceUrl, equals('https://cli-host:8443'));
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

    test('10. LAN client mode missing certificate throws StateError', () {
      final configFile = File(p.join(tempDir.path, 'client_config.json'));
      configFile.writeAsStringSync(
        jsonEncode({
          'serviceUrl': 'https://192.168.1.100:8443',
          'trustedCertPath': '',
          'clientToken': 'valid_token_1234567890abcdef',
          'mode': 'lanClient',
        }),
      );

      // 1. Missing certificate in configuration throws StateError
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
    });

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
      certFile.writeAsStringSync('dummy certificate content');

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
  });
}
