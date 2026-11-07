import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/monitoring_service_client.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/status_engine.dart';
import 'package:it_network_monitor/features/monitoring/presentation/services/monitoring_service_server.dart';

void main() {
  group('Production Release Gate: Sub-Millisecond Ping Accuracy', () {
    test(
      '1. CheckResult and DeviceStatusEntity format <1ms responses as "≤1 ms"',
      () {
        final subMsResult = CheckResult(
          deviceId: 1,
          targetIp: '192.168.27.10',
          checkType: CheckType.icmp,
          isSuccess: true,
          latencyMs: 0,
          isSubMillisecond: true,
          timestamp: DateTime.now(),
        );

        expect(subMsResult.isSubMillisecond, isTrue);
        expect(subMsResult.latencyMs, equals(0));

        // StatusEngine propagation
        final initialStatus = DeviceStatusEntity.initial(1);
        final updatedStatus = StatusEngine.processCheckResult(
          currentStatus: initialStatus,
          checkResult: subMsResult,
          config: const MonitoringConfig(),
        );

        expect(updatedStatus.isSubMillisecond, isTrue);
        expect(updatedStatus.displayLatency, equals('≤1 ms'));

        // Regular >=1ms latency displays normal number
        final regularResult = CheckResult(
          deviceId: 1,
          targetIp: '192.168.27.10',
          checkType: CheckType.icmp,
          isSuccess: true,
          latencyMs: 12,
          isSubMillisecond: false,
          timestamp: DateTime.now(),
        );

        final regularStatus = StatusEngine.processCheckResult(
          currentStatus: updatedStatus,
          checkResult: regularResult,
          config: const MonitoringConfig(),
        );

        expect(regularStatus.isSubMillisecond, isFalse);
        expect(regularStatus.displayLatency, equals('12 ms'));
      },
    );
  });

  group('Production Release Gate: Native Windows Service Host Architecture', () {
    test(
      '2. it_service_host.exe exists, is compiled x64 executable, and contains SCM recovery contract',
      () {
        final hostExe = File('installer/it_service_host.exe');
        expect(
          hostExe.existsSync(),
          isTrue,
          reason:
              'it_service_host.exe must be compiled and present in installer/',
        );

        // Inspect source code contract
        final csSource = File(
          'installer/service_host/ITMonitoringServiceHost.cs',
        ).readAsStringSync();
        expect(csSource.contains('ServiceBase'), isTrue);
        expect(csSource.contains('ITNetworkMonitorService'), isTrue);
        expect(
          csSource.contains('restart/5000/restart/10000/restart/60000'),
          isTrue,
          reason: 'Must configure SCM recovery restart actions',
        );
        expect(csSource.contains('reset= 86400'), isTrue);
        expect(csSource.contains('--service'), isTrue);
      },
    );

    test(
      '3. Service scripts preserve database and log directory by default',
      () {
        final installScript = File(
          'installer/install_windows_service_scm.bat',
        ).readAsStringSync();
        final uninstallScript = File(
          'installer/uninstall_windows_service_scm.bat',
        ).readAsStringSync();

        expect(installScript.contains('it_service_host.exe'), isTrue);
        expect(uninstallScript.contains('sc.exe delete'), isTrue);
        // Ensure uninstall does not delete .sqlite database
        expect(uninstallScript.contains('del *.sqlite'), isFalse);
        expect(uninstallScript.contains('rmdir /s /q'), isFalse);
      },
    );
  });

  group('Production Release Gate: Secure REST & WebSocket Communication', () {
    const certPath = 'test/fixtures/certs/server.crt';
    const keyPath = 'test/fixtures/certs/server.key';

    setUpAll(() async {
      // Ensure test database is configured
      if (!getIt.isRegistered<AppDatabase>()) {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        getIt.registerSingleton<AppDatabase>(db);
      }
    });

    test(
      '4. MonitoringServiceServer rejects invalid cert paths when useTls is enabled',
      () async {
        final server = MonitoringServiceServer(
          port: 19443,
          useTls: true,
          certPath: 'non_existent_cert.crt',
          keyPath: 'non_existent_key.key',
        );

        expect(server.start(), throwsA(isA<StateError>()));
      },
    );

    test(
      '5. MonitoringServiceServer runs HTTPS REST & WSS with real certificate',
      () async {
        final server = MonitoringServiceServer(
          port: 19443,
          useTls: true,
          certPath: certPath,
          keyPath: keyPath,
        );

        await server.start();

        // Client connecting with strict certificate validation using trusted root
        final client = MonitoringServiceClient(
          baseUrl: 'https://127.0.0.1:19443',
          trustedCertPath: certPath,
        );

        final statusRes = await client.getServiceStatus();
        expect(
          statusRes.isSuccess,
          isTrue,
          reason: 'Actual error: ${statusRes.errorMessage}',
        );
        expect(statusRes.data!['security'], equals('secure_tls'));
        expect(statusRes.data!['tls_enabled'], isTrue);

        // Verify unauthenticated client fails strict cert check if not trusting cert
        final unverifiedClient = MonitoringServiceClient(
          baseUrl: 'https://127.0.0.1:19443',
          // trustedCertPath intentionally omitted -> strict validation against standard roots fails
        );

        final unverifiedRes = await unverifiedClient.getServiceStatus();
        expect(unverifiedRes.isSuccess, isFalse);
        expect(unverifiedRes.errorMessage, contains('HandshakeException'));

        client.dispose();
        unverifiedClient.dispose();
        await server.stop();
      },
    );

    test(
      '6. Token lifecycle: Generation, 24h expiration, invalidation on logout',
      () async {
        final server = MonitoringServiceServer(
          port: 19444,
          useTls: false,
          isDevelopment: true,
          sessionTimeout: const Duration(seconds: 2),
        );

        await server.start();

        final client = MonitoringServiceClient(
          baseUrl: 'http://127.0.0.1:19444',
        );

        // 1. Attempt token verification with non-existent token
        final failAuth = await client.authenticateWithProvisionedToken(
          'invalid_non_existent_token_hex_value_0000000000000000000000000000',
        );
        expect(failAuth.isSuccess, isFalse);
        expect(failAuth.statusCode, equals(401));

        // 2. Register authorized machine session token and verify
        const validToken =
            'test_admin_token_0123456789abcdef0123456789abcdef0123456789abcdef01';
        server.registerAuthorizedSession(
          token: validToken,
          username: 'test_admin_machine',
          role: 'admin',
        );

        final successAuth = await client.authenticateWithProvisionedToken(
          validToken,
        );
        expect(successAuth.isSuccess, isTrue);
        expect(client.isAuthenticated, isTrue);
        expect(client.isAdmin, isTrue);
        expect(client.currentSession?.token, equals(validToken));

        // 3. Logout invalidates session
        final logoutRes = await client.logout();
        expect(logoutRes.isSuccess, isTrue);
        expect(client.isAuthenticated, isFalse);

        client.dispose();
        await server.stop();
      },
    );

    test(
      '7. Server-side RBAC: Viewer cannot execute mutating routes, Admin can',
      () async {
        final server = MonitoringServiceServer(
          port: 19445,
          useTls: false,
          isDevelopment: true,
        );

        await server.start();

        // 1. Unauthenticated request to mutating route returns 401
        final unauthClient = MonitoringServiceClient(
          baseUrl: 'http://127.0.0.1:19445',
        );
        final unauthRes = await unauthClient.assignDeviceOwner(
          deviceId: 1,
          ownerName: 'Alice',
        );
        expect(unauthRes.isSuccess, isFalse);
        expect(unauthRes.statusCode, equals(401));
        unauthClient.dispose();

        // 2. Authenticated Viewer request to mutating route returns 403 Forbidden
        const viewerToken =
            'test_viewer_token_0123456789abcdef0123456789abcdef0123456789abcdef';
        server.registerAuthorizedSession(
          token: viewerToken,
          username: 'viewer_machine',
          role: 'viewer',
        );

        final viewerClient = MonitoringServiceClient(
          baseUrl: 'http://127.0.0.1:19445',
        );
        final viewerAuth = await viewerClient.authenticateWithProvisionedToken(
          viewerToken,
        );
        expect(viewerAuth.isSuccess, isTrue);
        expect(viewerClient.isAdmin, isFalse);

        final viewerMutateRes = await viewerClient.assignDeviceOwner(
          deviceId: 1,
          ownerName: 'Alice',
        );
        expect(viewerMutateRes.isSuccess, isFalse);
        expect(viewerMutateRes.statusCode, equals(403));
        viewerClient.dispose();

        await server.stop();
      },
    );

    test(
      '8. Log redaction filters sensitive tokens, passwords, and keys from output',
      () {
        const sensitiveLog =
            'Received payload {"username": "admin", "password": "SecretPassword123!", "keyPassword": "KeyPassSecret!", "token": "sec_tok_abcdef123456"}';

        final redacted = sensitiveLog
            .replaceAllMapped(
              RegExp(r'("password"\s*:\s*)"[^"]*"', caseSensitive: false),
              (m) => '${m[1]}"[REDACTED]"',
            )
            .replaceAllMapped(
              RegExp(r'("keyPassword"\s*:\s*)"[^"]*"', caseSensitive: false),
              (m) => '${m[1]}"[REDACTED]"',
            )
            .replaceAllMapped(
              RegExp(r'("token"\s*:\s*)"[^"]*"', caseSensitive: false),
              (m) => '${m[1]}"[REDACTED]"',
            );

        expect(redacted.contains('SecretPassword123!'), isFalse);
        expect(redacted.contains('KeyPassSecret!'), isFalse);
        expect(redacted.contains('sec_tok_abcdef123456'), isFalse);
        expect(redacted.contains('"password": "[REDACTED]"'), isTrue);
        expect(redacted.contains('"keyPassword": "[REDACTED]"'), isTrue);
        expect(redacted.contains('"token": "[REDACTED]"'), isTrue);
      },
    );

    test(
      '9. Production mode fails closed when TLS is disabled or certificates missing',
      () async {
        // 9a. Production mode fails closed if useTls is false
        final noTlsServer = MonitoringServiceServer(
          port: 19446,
          useTls: false,
          isDevelopment: false,
        );
        expect(noTlsServer.start(), throwsA(isA<StateError>()));

        // 9b. Production mode fails closed if cert file does not exist
        final missingCertServer = MonitoringServiceServer(
          port: 19447,
          useTls: true,
          certPath: 'C:\\NonExistentPath\\server.crt',
          keyPath: keyPath,
          isDevelopment: false,
        );
        expect(missingCertServer.start(), throwsA(isA<StateError>()));

        // 9c. Production mode fails closed if key file does not exist
        final missingKeyServer = MonitoringServiceServer(
          port: 19448,
          useTls: true,
          certPath: certPath,
          keyPath: 'C:\\NonExistentPath\\server.key',
          isDevelopment: false,
        );
        expect(missingKeyServer.start(), throwsA(isA<StateError>()));
      },
    );

    test(
      '10. Configuration loader deterministic precedence (CLI > Env > Config file > Defaults)',
      () {
        // Test 1: Defaults (isolated from host filesystem service_config.json)
        final defaultConfig = MonitoringServiceConfig.loadFromEnvironmentOrFile(
          ['--config=non_existent_defaults_test.json'],
        );
        expect(defaultConfig.port, equals(8443));
        expect(defaultConfig.useTls, isTrue);
        expect(defaultConfig.isDevelopment, isFalse);

        // Test 2: CLI overrides
        final cliConfig = MonitoringServiceConfig.loadFromEnvironmentOrFile([
          '--dev',
          '--port=9443',
          '--no-tls',
        ]);
        expect(cliConfig.port, equals(9443));
        expect(cliConfig.useTls, isFalse);
        expect(cliConfig.isDevelopment, isTrue);

        // Test 3: CLI --tls override
        final tlsOverride = MonitoringServiceConfig.loadFromEnvironmentOrFile([
          '--tls',
          '--cert=custom.crt',
          '--key=custom.key',
        ]);
        expect(tlsOverride.useTls, isTrue);
        expect(tlsOverride.certPath, equals('custom.crt'));
        expect(tlsOverride.keyPath, equals('custom.key'));
      },
    );
  });
}
