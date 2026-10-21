import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/platform_ping_checker.dart';
import 'package:it_network_monitor/features/network_discovery/data/datasources/strategies/icmp_discovery_strategy.dart';

void main() {
  group('IcmpDiscoveryStrategy Unit & Adversarial Tests', () {
    final strategy = IcmpDiscoveryStrategy();

    test('1. Strategy name is icmp', () {
      expect(strategy.name, equals('icmp'));
    });

    test('2. Rejects invalid malformed target IP addresses', () async {
      final res = await strategy.probe(
        'invalid.ip.format',
        const Duration(milliseconds: 500),
      );
      expect(res.isSuccess, isFalse);
    });

    test(
      '3. Verification that parsePingOutput integration preserves strict IP boundary for discovery',
      () {
        // Direct verification that neighbor .60 or .64 does not falsely validate .6 in discovery
        const neighborOutput = '''
Pinging 192.168.27.6 with 32 bytes of data:
Reply from 192.168.27.60: bytes=32 time=4ms TTL=64
''';

        final parsed = PlatformPingChecker.parsePingOutput(
          stdout: neighborOutput,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.27.6',
        );

        expect(parsed.isSuccess, isFalse);
        expect(parsed.respondingSourceIp, equals('192.168.27.60'));
      },
    );

    test(
      '4. Verification that gateway unreachable reply does not count as target host response in discovery',
      () {
        const gwUnreachable = '''
Pinging 192.168.27.240 with 32 bytes of data:
Reply from 192.168.27.1: Destination host unreachable.
''';

        final parsed = PlatformPingChecker.parsePingOutput(
          stdout: gwUnreachable,
          stderr: '',
          exitCode: 1,
          targetIp: '192.168.27.240',
        );

        expect(parsed.isSuccess, isFalse);
        expect(parsed.respondingSourceIp, equals('192.168.27.1'));
      },
    );
  });
}
