import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/core/utils/password_hash.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/inventory_import_preview.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/presentation/services/monitoring_service_server.dart';
import 'package:drift/native.dart';

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

    // Setup an in-memory database and register dependencies if not already registered
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

  group('Phase 1 Security & Authorization Regression Tests', () {
    test(
      '1. Machine-bound trusted client token is provisioned on server startup',
      () async {
        expect(server.trustedClientToken, isNotNull);
        expect(
          server.trustedClientToken!.length,
          equals(64),
        ); // 32 bytes hex encoded
        expect(server.trustedTokenFilePath, isNotNull);

        final tokenFile = File(server.trustedTokenFilePath!);
        expect(tokenFile.existsSync(), isTrue);
        final fileContent = tokenFile.readAsStringSync().trim();
        expect(fileContent, equals(server.trustedClientToken));
      },
    );

    test(
      '2. Unauthenticated requests to all sensitive GET endpoints return 401 Unauthorized',
      () async {
        final sensitiveEndpoints = [
          '/api/devices',
          '/api/infrastructure/unifi/devices',
          '/api/incidents',
          '/api/topology',
          '/api/settings',
          '/api/reports/summary',
          '/api/discovery/config',
          '/api/discovery/status',
          '/api/discovery/devices',
        ];

        for (final endpoint in sensitiveEndpoints) {
          final req = await httpClient.get('127.0.0.1', serverPort, endpoint);
          final res = await req.close();
          final body = await utf8.decoder.bind(res).join();

          expect(
            res.statusCode,
            equals(401),
            reason:
                'Endpoint $endpoint must reject unauthenticated requests with 401',
          );
          expect(body, contains('Unauthorized'));
        }
      },
    );

    test(
      '3. Query parameter ?token= is NOT accepted for authentication (prevents URL leakage)',
      () async {
        final trustedToken = server.trustedClientToken!;
        // Attempt to access with token in query param
        final req = await httpClient.get(
          '127.0.0.1',
          serverPort,
          '/api/devices?token=$trustedToken',
        );
        final res = await req.close();

        expect(
          res.statusCode,
          equals(401),
          reason:
              'Tokens passed in query parameters must be rejected to prevent URL leakage',
        );
      },
    );

    test(
      '4. WebSocket upgrade on /ws rejects unauthenticated requests with 401',
      () async {
        final req = await httpClient.get('127.0.0.1', serverPort, '/ws');
        req.headers.set('Connection', 'Upgrade');
        req.headers.set('Upgrade', 'websocket');
        req.headers.set('Sec-WebSocket-Version', '13');
        req.headers.set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==');
        final res = await req.close();

        expect(
          res.statusCode,
          equals(401),
          reason:
              'WebSocket upgrade must reject unauthenticated clients with 401',
        );
      },
    );

    test(
      '5. Public /api/health endpoint returns minimal operational data without sensitive leaks',
      () async {
        final req = await httpClient.get(
          '127.0.0.1',
          serverPort,
          '/api/health',
        );
        final res = await req.close();
        final bodyStr = await utf8.decoder.bind(res).join();
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        expect(res.statusCode, equals(200));
        expect(body['status'], isIn(['ok', 'online']));
        expect(body.containsKey('uptime_seconds'), isTrue);
        // Ensure no sensitive inventory, devices, or settings are exposed
        expect(body.containsKey('devices'), isFalse);
        expect(body.containsKey('settings'), isFalse);
        expect(body.containsKey('credentials'), isFalse);
        expect(body.containsKey('activeSessions'), isFalse);
      },
    );

    test(
      '6. Authenticated request using trusted machine-local token succeeds with 200',
      () async {
        final trustedToken = server.trustedClientToken!;
        final req = await httpClient.get(
          '127.0.0.1',
          serverPort,
          '/api/devices',
        );
        req.headers.set('Authorization', 'Bearer $trustedToken');
        final res = await req.close();

        expect(
          res.statusCode,
          equals(200),
          reason:
              'Valid trusted local client token must grant authorized access',
        );
      },
    );

    test(
      '7. Unauthorized roles receive 403 Forbidden for administrative operations',
      () async {
        // Create a viewer user in the database
        final viewerPassword = 'ViewerPassword123!';
        final viewerHash = PasswordHash.hashPassword(viewerPassword);
        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                username: 'audit_viewer',
                passwordHash: viewerHash,
                role: const Value('viewer'),
              ),
            );

        // Login as viewer
        final loginReq = await httpClient.post(
          '127.0.0.1',
          serverPort,
          '/api/auth/login',
        );
        loginReq.headers.contentType = ContentType.json;
        loginReq.write(
          jsonEncode({'username': 'audit_viewer', 'password': viewerPassword}),
        );
        final loginRes = await loginReq.close();
        expect(loginRes.statusCode, equals(200));
        final loginBody =
            jsonDecode(await utf8.decoder.bind(loginRes).join())
                as Map<String, dynamic>;
        final viewerToken = loginBody['token'] as String;

        // Viewer CAN read sensitive devices with 200
        final readReq = await httpClient.get(
          '127.0.0.1',
          serverPort,
          '/api/devices',
        );
        readReq.headers.set('Authorization', 'Bearer $viewerToken');
        final readRes = await readReq.close();
        expect(readRes.statusCode, equals(200));

        // Viewer CANNOT access admin service config (must return 403)
        final adminReq = await httpClient.get(
          '127.0.0.1',
          serverPort,
          '/api/admin/service-config',
        );
        adminReq.headers.set('Authorization', 'Bearer $viewerToken');
        final adminRes = await adminReq.close();
        expect(
          adminRes.statusCode,
          equals(403),
          reason:
              'Viewer must receive 403 Forbidden on administrative endpoints',
        );

        // Viewer CANNOT mutate device ownership (must return 403)
        final mutateReq = await httpClient.post(
          '127.0.0.1',
          serverPort,
          '/api/devices/assign-owner',
        );
        mutateReq.headers.set('Authorization', 'Bearer $viewerToken');
        mutateReq.headers.contentType = ContentType.json;
        mutateReq.write(jsonEncode({'deviceId': 1, 'ownerName': 'Hacker'}));
        final mutateRes = await mutateReq.close();
        expect(
          mutateRes.statusCode,
          equals(403),
          reason:
              'Viewer must receive 403 Forbidden when attempting device mutations',
        );
      },
    );

    test(
      '8. Trusted client token file is deleted when service stops',
      () async {
        final tokenPath = server.trustedTokenFilePath!;
        expect(File(tokenPath).existsSync(), isTrue);

        await server.stop();
        expect(File(tokenPath).existsSync(), isFalse);
      },
    );
  });
}
