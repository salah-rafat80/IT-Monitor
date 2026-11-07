import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/monitoring_service_client.dart';
import 'package:it_network_monitor/features/monitoring/presentation/services/monitoring_service_server.dart';

void main() {
  group(
    'Phase 1.1 -- Machine Authentication & Token Verification (No Interactive Login)',
    () {
      test(
        'Machine authentication & token verification work without interactive login',
        () async {
          final server = MonitoringServiceServer(
            port: 19488,
            useTls: false,
            isDevelopment: true,
          );
          await server.start();

          const testToken =
              'machine_token_phase1_cleanup_audit_verify_0123456789abcdef';
          server.registerAuthorizedSession(
            token: testToken,
            username: 'provisioned_agent',
            role: 'admin',
          );

          final client = MonitoringServiceClient(
            baseUrl: 'http://127.0.0.1:19488',
          );

          // Verify invalid token is rejected
          final badRes = await client.authenticateWithProvisionedToken(
            'bad_token',
          );
          expect(badRes.isSuccess, isFalse);
          expect(badRes.statusCode, equals(401));

          // Verify provisioned token is accepted
          final okRes = await client.authenticateWithProvisionedToken(
            testToken,
          );
          expect(okRes.isSuccess, isTrue);
          expect(client.isAuthenticated, isTrue);
          expect(client.isAdmin, isTrue);
          expect(client.currentSession?.username, equals('provisioned_agent'));

          // Verify logout invalidates the token
          final logoutRes = await client.logout();
          expect(logoutRes.isSuccess, isTrue);
          expect(client.isAuthenticated, isFalse);

          client.dispose();
          await server.stop();
        },
      );
    },
  );
}
