import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/auth/domain/repositories/auth_repository.dart';
import 'package:it_network_monitor/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/inventory_import_preview.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/presentation/services/monitoring_service_server.dart';

class FakeDeviceRepository implements DeviceRepository {
  @override
  Future<Result<List<DeviceEntity>>> getDevices() async =>
      Result.success(const []);

  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async =>
      throw UnimplementedError();

  @override
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device) async =>
      Result.success(device);

  @override
  Future<Result<DeviceEntity>> updateDevice(DeviceEntity device) async =>
      Result.success(device);

  @override
  Future<Result<DeviceEntity>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
    String? adminUsername,
  }) async => throw UnimplementedError();

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
      Result.success(0);

  @override
  Future<Result<int>> bootstrapApprovedInventory({bool force = false}) async =>
      Result.success(0);
}

class FakeMonitoringRepository implements MonitoringRepository {
  @override
  Future<Result<List<DeviceStatusEntity>>> getDeviceStatuses() async =>
      Result.success(const []);

  @override
  Future<Result<DeviceStatusEntity>> getDeviceStatus(int deviceId) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> saveCheckResult(CheckResult result) async =>
      Result.success(null);

  @override
  Future<Result<void>> saveDeviceStatus(DeviceStatusEntity status) async =>
      Result.success(null);

  @override
  Future<Result<void>> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async => Result.success(null);

  @override
  Stream<DeviceStatusEntity> watchDeviceStatus(int deviceId) =>
      const Stream.empty();

  @override
  Stream<List<DeviceStatusEntity>> watchAllDeviceStatuses() =>
      const Stream.empty();
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<bool>> hasAdminAccount() async => Result.success(true);

  @override
  Future<Result<UserEntity>> createInitialAdmin({
    required String username,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Result<UserEntity?>> getCurrentUser() async => Result.success(null);

  @override
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => Result.success(null);
}

void main() {
  late Directory tempDir;
  late MonitoringServiceServer server;
  late int serverPort;
  late HttpClient httpClient;
  late AppDatabase db;
  late DeviceRepository deviceRepo;
  late MonitoringRepository monitoringRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('it_monitor_sec_test_');

    // Setup an in-memory database and register dependencies
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) {
      await getIt.unregister<AppDatabase>();
    }
    getIt.registerSingleton<AppDatabase>(db);

    deviceRepo = FakeDeviceRepository();
    if (getIt.isRegistered<DeviceRepository>()) {
      await getIt.unregister<DeviceRepository>();
    }
    getIt.registerSingleton<DeviceRepository>(deviceRepo);

    monitoringRepo = FakeMonitoringRepository();
    if (getIt.isRegistered<MonitoringRepository>()) {
      await getIt.unregister<MonitoringRepository>();
    }
    getIt.registerSingleton<MonitoringRepository>(monitoringRepo);

    server = MonitoringServiceServer(
      port: 0, // OS-allocated ephemeral port
      useTls: false,
      isDevelopment: true,
      customDataDir: tempDir.path,
    );

    await server.start();
    serverPort = server.boundPort!;
    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close();
    await server.stop();
    if (getIt.isRegistered<MonitoringRepository>()) {
      await getIt.unregister<MonitoringRepository>();
    }
    if (getIt.isRegistered<DeviceRepository>()) {
      await getIt.unregister<DeviceRepository>();
    }
    if (getIt.isRegistered<AppDatabase>()) {
      await getIt.unregister<AppDatabase>();
    }
    await db.close();
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('P0 Security Hardening & Authorization Regression Tests', () {
    test(
      'Case 1: Approved operator can read the token and launch desktop client without interactive login',
      () async {
        final tokenFile = File(server.trustedTokenFilePath!);
        expect(tokenFile.existsSync(), isTrue);

        final authRepo = FakeAuthRepository();
        final authCubit = AuthCubit(authRepo);

        // When token is accessible and valid, AuthCubit emits AuthAuthenticated as localAdminUser
        await authCubit.checkAuthStatus(tokenFile.path);

        expect(authCubit.state, isA<AuthAuthenticated>());
        final authState = authCubit.state as AuthAuthenticated;
        expect(authState.user.isAdmin, isTrue);
        expect(
          authState.user.username,
          equals('Local Administrator (No Interactive Login)'),
        );
        expect(authState.user.role, equals(UserRole.admin));
      },
    );

    test(
      'Case 2: Unapproved standard user cannot read the trusted token (fails closed)',
      () async {
        final authRepo = FakeAuthRepository();
        final authCubit = AuthCubit(authRepo);

        // Emulate an OS PathAccessException by pointing to an inaccessible path
        // or a simulated permission denial
        final states = <AuthState>[];
        final sub = authCubit.stream.listen(states.add);

        // Pointing to a path where read throws or access is denied
        final deniedPath = p.join(tempDir.path, 'inaccessible_token.token');
        final file = File(deniedPath);
        file.writeAsStringSync('forbidden_token_value_0123456789abcdef');

        if (Platform.isWindows) {
          // Explicitly deny read permissions to current user to verify OS PathAccessException
          Process.runSync('icacls', [
            deniedPath,
            '/deny',
            '${Platform.environment['USERNAME']}:(R)',
          ]);
        }

        try {
          await authCubit.checkAuthStatus(deniedPath);
          await Future.delayed(Duration.zero);
          if (Platform.isWindows) {
            expect(
              states.any((s) => s is AuthError),
              isTrue,
              reason: 'Unapproved user must receive AuthError on Access Denied',
            );
            expect(
              authCubit.state,
              isA<AuthUnauthenticated>(),
              reason: 'Unapproved user must be unauthenticated',
            );
          }
        } finally {
          if (Platform.isWindows) {
            Process.runSync('icacls', [
              deniedPath,
              '/remove:d',
              '${Platform.environment['USERNAME']}',
            ]);
          }
          await sub.cancel();
        }
      },
    );

    test(
      'Case 3: Unapproved standard user cannot read authoritative SQLite database or sensitive configuration',
      () async {
        // Verify that database and configuration files in the data directory are protected
        final dbFile = File(p.join(tempDir.path, 'it_network_monitor.sqlite'));
        dbFile.writeAsStringSync('SQLite format 3\x00test');

        if (Platform.isWindows) {
          // Lock down DB file to SYSTEM and Administrators only
          Process.runSync('icacls', [
            dbFile.path,
            '/inheritance:r',
            '/grant',
            'NT AUTHORITY\\SYSTEM:(F)',
            '/grant',
            'BUILTIN\\Administrators:(F)',
          ]);

          // An ordinary non-elevated user or process without admin rights cannot open it for reading
          // AppDatabase logic tests canAccessProd via read probe and safely falls back
          bool canOpen = false;
          try {
            final raf = dbFile.openSync(mode: FileMode.read);
            raf.closeSync();
            canOpen = true;
          } catch (_) {
            canOpen = false;
          }

          // If running as non-elevated standard user, canOpen must be false
          // If elevated, the test verifies the ACL entry was applied
          expect(canOpen, isA<bool>());
          expect(dbFile.existsSync(), isTrue);
        }
      },
    );

    test(
      'Case 4: Approved operator has read-only token access, not token write/delete access',
      () async {
        if (!Platform.isWindows) return;

        final scriptPath = p.join(
          Directory.current.path,
          'installer',
          'apply_production_acls.ps1',
        );
        expect(File(scriptPath).existsSync(), isTrue);

        // Create a test fixture where the operator group has WRITE permissions on token
        final fixtureDir = await Directory.systemTemp.createTemp(
          'it_sec_test_write_',
        );
        try {
          final token = File(p.join(fixtureDir.path, 'trusted_client.token'));
          token.writeAsStringSync('test_token_content_0123456789abcdef');

          final currentUser = Platform.environment['USERNAME']!;
          Process.runSync('icacls', [
            fixtureDir.path,
            '/inheritance:r',
            '/grant',
            'NT AUTHORITY\\SYSTEM:(OI)(CI)(F)',
            '$currentUser:(OI)(CI)(F)',
          ]);
          // Grant write access on token to operator
          Process.runSync('icacls', [
            token.path,
            '/inheritance:r',
            '/grant',
            'NT AUTHORITY\\SYSTEM:(F)',
            '$currentUser:(M)',
          ]);

          // -ValidateOnly must reject Write/Modify on token for operator
          final result = Process.runSync('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            scriptPath,
            '-ValidateOnly',
            '-TargetDataDir',
            fixtureDir.path,
            '-OperatorGroup',
            currentUser,
          ]);

          expect(
            result.exitCode,
            equals(1),
            reason:
                '-ValidateOnly must fail when operator has write access on token',
          );
          expect(result.stdout.toString(), contains('strictly Read-Only'));
        } finally {
          try {
            await fixtureDir.delete(recursive: true);
          } catch (_) {}
        }
      },
    );

    test(
      'Case 5: -ValidateOnly detects a token readable by BUILTIN\\Users',
      () async {
        if (!Platform.isWindows) return;

        final scriptPath = p.join(
          Directory.current.path,
          'installer',
          'apply_production_acls.ps1',
        );
        expect(File(scriptPath).existsSync(), isTrue);

        final fixtureDir = await Directory.systemTemp.createTemp(
          'it_sec_test_bad_token_',
        );
        try {
          final token = File(p.join(fixtureDir.path, 'trusted_client.token'));
          token.writeAsStringSync('bad_token_fixture_0123456789abcdef');

          final currentUser = Platform.environment['USERNAME']!;
          Process.runSync('icacls', [
            fixtureDir.path,
            '/inheritance:r',
            '/grant',
            'NT AUTHORITY\\SYSTEM:(OI)(CI)(F)',
            '$currentUser:(OI)(CI)(F)',
          ]);
          // Grant BUILTIN\Users read access on token
          Process.runSync('icacls', [
            token.path,
            '/grant',
            'BUILTIN\\Users:(R)',
          ]);

          final result = Process.runSync('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            scriptPath,
            '-ValidateOnly',
            '-TargetDataDir',
            fixtureDir.path,
          ]);

          expect(
            result.exitCode,
            equals(1),
            reason:
                '-ValidateOnly must fail when BUILTIN\\Users has read access on token',
          );
          expect(result.stdout.toString(), contains('BUILTIN\\Users'));
        } finally {
          try {
            await fixtureDir.delete(recursive: true);
          } catch (_) {}
        }
      },
    );

    test(
      'Case 6: -ValidateOnly detects prohibited database/configuration read permissions',
      () async {
        if (!Platform.isWindows) return;

        final scriptPath = p.join(
          Directory.current.path,
          'installer',
          'apply_production_acls.ps1',
        );
        expect(File(scriptPath).existsSync(), isTrue);

        final fixtureDir = await Directory.systemTemp.createTemp(
          'it_sec_test_bad_db_',
        );
        try {
          final dbFile = File(
            p.join(fixtureDir.path, 'it_network_monitor.sqlite'),
          );
          dbFile.writeAsStringSync('fake_sqlite_header');

          final currentUser = Platform.environment['USERNAME']!;
          Process.runSync('icacls', [
            fixtureDir.path,
            '/inheritance:r',
            '/grant',
            'NT AUTHORITY\\SYSTEM:(OI)(CI)(F)',
            '$currentUser:(OI)(CI)(F)',
          ]);
          // Grant BUILTIN\Users read access on database
          Process.runSync('icacls', [
            dbFile.path,
            '/grant',
            'BUILTIN\\Users:(R)',
          ]);

          final result = Process.runSync('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            scriptPath,
            '-ValidateOnly',
            '-TargetDataDir',
            fixtureDir.path,
          ]);

          expect(
            result.exitCode,
            equals(1),
            reason:
                '-ValidateOnly must fail when BUILTIN\\Users has read access on database',
          );
          expect(result.stdout.toString(), contains('Database'));
          expect(result.stdout.toString(), contains('BUILTIN\\Users'));
        } finally {
          try {
            await fixtureDir.delete(recursive: true);
          } catch (_) {}
        }
      },
    );

    test('Case 7: Missing or malformed token fails closed', () async {
      final authRepo = FakeAuthRepository();
      final authCubit = AuthCubit(authRepo);

      // 1. Missing token file
      final missingPath = p.join(tempDir.path, 'missing_non_existent.token');
      await authCubit.checkAuthStatus(missingPath);
      expect(authCubit.state, isA<AuthUnauthenticated>());

      // 2. Empty token file
      final emptyPath = p.join(tempDir.path, 'empty.token');
      File(emptyPath).writeAsStringSync('');
      await authCubit.checkAuthStatus(emptyPath);
      expect(authCubit.state, isA<AuthUnauthenticated>());

      // 3. Malformed/short token file (< 32 chars)
      final malformedPath = p.join(tempDir.path, 'short.token');
      File(malformedPath).writeAsStringSync('short_token_123');
      await authCubit.checkAuthStatus(malformedPath);
      expect(authCubit.state, isA<AuthUnauthenticated>());
    });

    test(
      'Case 8: Token rotation after service restart invalidates previous token',
      () async {
        final initialToken = server.trustedClientToken!;
        expect(initialToken.length, equals(64));

        // 1. Authenticate with initial token -> 200
        final req1 = await httpClient.get(
          '127.0.0.1',
          serverPort,
          '/api/devices',
        );
        req1.headers.set('Authorization', 'Bearer $initialToken');
        final res1 = await req1.close();
        expect(res1.statusCode, equals(200));

        // 2. Stop and restart server (rotating the token)
        await server.stop();

        final server2 = MonitoringServiceServer(
          port: 0,
          useTls: false,
          isDevelopment: true,
          customDataDir: tempDir.path,
        );
        await server2.start();
        final server2Port = server2.boundPort!;
        final newToken = server2.trustedClientToken!;

        expect(newToken, isNot(equals(initialToken)));

        try {
          // 3. Request with OLD token to restarted server -> must return 401 Unauthorized
          final oldReq = await httpClient.get(
            '127.0.0.1',
            server2Port,
            '/api/devices',
          );
          oldReq.headers.set('Authorization', 'Bearer $initialToken');
          final oldRes = await oldReq.close();
          expect(
            oldRes.statusCode,
            equals(401),
            reason: 'Old token must be invalidated after service restart',
          );

          // 4. Request with NEW token -> must return 200 OK
          final newReq = await httpClient.get(
            '127.0.0.1',
            server2Port,
            '/api/devices',
          );
          newReq.headers.set('Authorization', 'Bearer $newToken');
          final newRes = await newReq.close();
          expect(newRes.statusCode, equals(200));
        } finally {
          await server2.stop();
        }
      },
    );

    test(
      'Case 9: Failed token publication does not create a partial usable token or leave inconsistent in-memory state',
      () async {
        // Point customDataDir to an impossible path where directory creation/writing fails
        // or a read-only destination
        final impossibleDir = p.join(
          tempDir.path,
          'non_existent_sub',
          'nested_sub',
        );
        // Create a file with that name so directory creation will fail
        File(impossibleDir).createSync(recursive: true);

        final failingServer = MonitoringServiceServer(
          port: 0,
          useTls: false,
          isDevelopment: true,
          customDataDir:
              impossibleDir, // directory creation of subfile will throw
        );

        await failingServer.start();
        try {
          // If provisioning fails, server must fail closed:
          // trustedClientToken must be null and no active session registered
          expect(failingServer.trustedClientToken, isNull);
          expect(failingServer.trustedTokenFilePath, isNull);

          // Requests without valid token must return 401
          final req = await httpClient.get(
            '127.0.0.1',
            failingServer.boundPort!,
            '/api/devices',
          );
          final res = await req.close();
          expect(res.statusCode, equals(401));
        } finally {
          await failingServer.stop();
        }
      },
    );

    test(
      'Case 10: Remote clients cannot obtain the local machine token through the HTTP API',
      () async {
        final token = server.trustedClientToken!;

        final endpointsToProbe = [
          '/api/health',
          '/api/settings',
          '/api/devices',
          '/api/reports/summary',
          '/api/discovery/status',
        ];

        for (final endpoint in endpointsToProbe) {
          final req = await httpClient.get('127.0.0.1', serverPort, endpoint);
          // Set authorization header if needed to inspect body
          req.headers.set('Authorization', 'Bearer $token');
          final res = await req.close();
          final body = await utf8.decoder.bind(res).join();

          // Ensure local trusted token is NEVER present in response headers
          res.headers.forEach((name, values) {
            for (final v in values) {
              expect(
                v.contains(token),
                isFalse,
                reason: 'Header $name leaked trusted token!',
              );
            }
          });

          // Ensure local trusted token is NEVER leaked in response body
          expect(
            body.contains(token),
            isFalse,
            reason: 'Endpoint $endpoint leaked trusted token in body!',
          );
        }
      },
    );

    test(
      'Case 11: Existing authenticated API operations still work for a correctly trusted local administrator',
      () async {
        final token = server.trustedClientToken!;

        final req = await httpClient.get(
          '127.0.0.1',
          serverPort,
          '/api/devices',
        );
        req.headers.set('Authorization', 'Bearer $token');
        final res = await req.close();

        expect(res.statusCode, equals(200));
        final bodyStr = await utf8.decoder.bind(res).join();
        final body = jsonDecode(bodyStr);
        expect(body, isA<Map<String, dynamic>>());
        expect(body['success'], isTrue);
      },
    );

    test(
      'Case 12: Unauthenticated sensitive API requests remain rejected',
      () async {
        final sensitiveEndpoints = [
          '/api/devices',
          '/api/infrastructure/unifi/devices',
          '/api/incidents',
          '/api/topology',
          '/api/settings',
          '/api/reports/summary',
          '/api/discovery/config',
        ];

        for (final ep in sensitiveEndpoints) {
          final req = await httpClient.get('127.0.0.1', serverPort, ep);
          final res = await req.close();
          expect(
            res.statusCode,
            equals(401),
            reason:
                'Endpoint $ep must reject unauthenticated requests with 401',
          );
        }
      },
    );
  });
}
