import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/platform_ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';

void main() {
  group('PlatformPingChecker.parsePingOutput Adversarial & Forensic Tests', () {
    test('1. Exact target IP Echo Reply returns success with latency', () {
      const stdout = '''
Pinging 192.168.27.6 with 32 bytes of data:
Reply from 192.168.27.6: bytes=32 time=4ms TTL=64

Ping statistics for 192.168.27.6:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 4ms, Maximum = 4ms, Average = 4ms
''';

      final res = PlatformPingChecker.parsePingOutput(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        targetIp: '192.168.27.6',
      );

      expect(res.isSuccess, isTrue);
      expect(res.latencyMs, equals(4));
      expect(res.isSubMillisecond, isFalse);
      expect(res.respondingSourceIp, equals('192.168.27.6'));
      expect(res.failureReason, equals(PingFailureReason.none));
    });

    test(
      '2. Substring IP collision (.64 responding when target is .6) must NOT match',
      () {
        const stdout = '''
Pinging 192.168.27.6 with 32 bytes of data:
Reply from 192.168.27.64: bytes=32 time=2ms TTL=64

Ping statistics for 192.168.27.6:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.27.6',
        );

        // Must be classified as failure or wrongSourceIp, NEVER a success for 192.168.27.6
        expect(res.isSuccess, isFalse);
        expect(res.latencyMs, isNull);
        expect(res.respondingSourceIp, equals('192.168.27.64'));
      },
    );

    test(
      '3. Substring IP collision (.60 responding when target is .6) must NOT match',
      () {
        const stdout = '''
Pinging 192.168.27.6 with 32 bytes of data:
Reply from 192.168.27.60: bytes=32 time=3ms TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.27.6',
        );

        expect(res.isSuccess, isFalse);
        expect(res.latencyMs, isNull);
        expect(res.respondingSourceIp, equals('192.168.27.60'));
      },
    );

    test(
      '4. Substring IP collision (.6 responding when target is .60) must NOT match',
      () {
        const stdout = '''
Pinging 192.168.27.60 with 32 bytes of data:
Reply from 192.168.27.6: bytes=32 time=3ms TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.27.60',
        );

        expect(res.isSuccess, isFalse);
        expect(res.latencyMs, isNull);
        expect(res.respondingSourceIp, equals('192.168.27.6'));
      },
    );

    test(
      '5. Sub-millisecond latency (time<1ms) returns latency 1 with isSubMillisecond flag',
      () {
        const stdout = '''
Pinging 192.168.1.1 with 32 bytes of data:
Reply from 192.168.1.1: bytes=32 time<1ms TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.1.1',
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(1));
        expect(res.isSubMillisecond, isTrue);
      },
    );

    test(
      '6. Linux ping format (bytes from target IP: icmp_seq=1 ttl=64 time=0.45 ms)',
      () {
        const stdout = '''
PING 10.0.0.5 (10.0.0.5) 56(84) bytes of data.
64 bytes from 10.0.0.5: icmp_seq=1 ttl=64 time=0.45 ms

--- 10.0.0.5 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.450/0.450/0.450/0.000 ms
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '10.0.0.5',
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(1)); // Rounded up to 1 for <1ms
        expect(res.isSubMillisecond, isTrue);
      },
    );

    test(
      '7. Destination host unreachable responded by gateway (192.168.27.1 when target is 192.168.27.200)',
      () {
        const stdout = '''
Pinging 192.168.27.200 with 32 bytes of data:
Reply from 192.168.27.1: Destination host unreachable.

Ping statistics for 192.168.27.200:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 1,
          targetIp: '192.168.27.200',
        );

        expect(res.isSuccess, isFalse);
        expect(res.latencyMs, isNull);
        expect(
          res.failureReason,
          equals(PingFailureReason.destinationUnreachable),
        );
        expect(res.respondingSourceIp, equals('192.168.27.1'));
      },
    );

    test('8. Target IP with unexpected whitespace normalizes correctly', () {
      const stdout = '''
Pinging 192.168.27.6 with 32 bytes of data:
Reply from 192.168.27.6: bytes=32 time=5ms TTL=128
''';

      final res = PlatformPingChecker.parsePingOutput(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        targetIp: '   192.168.27.6   \n',
      );

      expect(res.isSuccess, isTrue);
      expect(res.latencyMs, equals(5));
      expect(res.respondingSourceIp, equals('192.168.27.6'));
    });

    test('9. TTL expired in transit must NOT be counted as success', () {
      const stdout = '''
Pinging 192.168.27.6 with 32 bytes of data:
Reply from 192.168.27.1: TTL expired in transit.
''';

      final res = PlatformPingChecker.parsePingOutput(
        stdout: stdout,
        stderr: '',
        exitCode: 1,
        targetIp: '192.168.27.6',
      );

      expect(res.isSuccess, isFalse);
      expect(res.latencyMs, isNull);
      expect(res.failureReason, isNot(equals(PingFailureReason.none)));
    });

    test(
      '10. 100% packet loss with stale average latency must NOT count as success',
      () {
        const stdout = '''
Pinging 192.168.27.99 with 32 bytes of data:
Request timed out.

Ping statistics for 192.168.27.99:
    Packets: Sent = 1, Received = 0, Lost = 1 (100% loss),
Approximate round trip times in milli-seconds:
    Minimum = 0ms, Maximum = 0ms, Average = 0ms
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 1,
          targetIp: '192.168.27.99',
        );

        expect(res.isSuccess, isFalse);
        expect(res.latencyMs, isNull);
        expect(res.failureReason, equals(PingFailureReason.timeout));
      },
    );

    test('11. General network failure / Transmit failed', () {
      const stdout = '''
Pinging 192.168.1.1 with 32 bytes of data:
General failure.

Ping statistics for 192.168.1.1:
    Packets: Sent = 1, Received = 0, Lost = 1 (100% loss),
''';

      final res = PlatformPingChecker.parsePingOutput(
        stdout: stdout,
        stderr: '',
        exitCode: 1,
        targetIp: '192.168.1.1',
      );

      expect(res.isSuccess, isFalse);
      expect(res.latencyMs, isNull);
      expect(
        res.failureReason,
        equals(PingFailureReason.generalNetworkFailure),
      );
    });

    test(
      '12. Localized Windows ping: German (Antwort von ... Zeit=12ms TTL=64)',
      () {
        const stdout = '''
Ping wird ausgeführt für 192.168.1.1 mit 32 Bytes Daten:
Antwort von 192.168.1.1: Bytes=32 Zeit=12ms TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.1.1',
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(12));
        expect(res.respondingSourceIp, equals('192.168.1.1'));
      },
    );

    test(
      '13. Localized Windows ping: French (Réponse de ... temps=8 ms TTL=64)',
      () {
        const stdout = '''
Envoi d'une requête 'Ping'  192.168.1.1 avec 32 octets de données :
Réponse de 192.168.1.1 : octets=32 temps=8 ms TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.1.1',
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(8));
        expect(res.respondingSourceIp, equals('192.168.1.1'));
      },
    );

    test(
      '14. Localized Windows ping: Arabic (الرد من ... الوقت=5ms TTL=64)',
      () {
        const stdout = '''
Pinging 192.168.1.1 with 32 bytes of data:
الرد من 192.168.1.1: وحدات البايت=32 الوقت=5ms TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: '192.168.1.1',
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(5));
        expect(res.respondingSourceIp, equals('192.168.1.1'));
      },
    );
  });
}
