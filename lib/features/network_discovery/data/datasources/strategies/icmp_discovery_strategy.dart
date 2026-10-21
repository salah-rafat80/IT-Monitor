import 'dart:io';
import 'package:injectable/injectable.dart';

import '../../../domain/services/discovery_strategy.dart';
import '../../../../monitoring/data/datasources/platform_ping_checker.dart';

@lazySingleton
class IcmpDiscoveryStrategy implements DiscoveryStrategy {
  @override
  String get name => 'icmp';

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    try {
      final List<String> args = [];
      if (Platform.isWindows) {
        args.addAll([
          '-n',
          '1',
          '-w',
          '${timeout.inMilliseconds}',
          targetIp.trim(),
        ]);
      } else {
        args.addAll(['-c', '1', '-W', '${timeout.inSeconds}', targetIp.trim()]);
      }

      final result = await Process.run('ping', args, runInShell: true).timeout(
        timeout + const Duration(seconds: 1),
        onTimeout: () => ProcessResult(-1, -1, '', 'Ping execution timeout'),
      );

      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();

      final parsed = PlatformPingChecker.parsePingOutput(
        stdout: stdout,
        stderr: stderr,
        exitCode: result.exitCode,
        targetIp: targetIp,
      );

      if (parsed.isSuccess) {
        return StrategyProbeResult.success(
          strategyName: name,
          targetIp: targetIp,
          latencyMs: parsed.latencyMs,
          evidenceDetails:
              'ICMP Echo reply received (${parsed.latencyMs ?? 0}ms)',
        );
      } else {
        final err = parsed.errorMessage.isNotEmpty
            ? parsed.errorMessage
            : 'No ICMP response';
        return StrategyProbeResult.failure(
          strategyName: name,
          targetIp: targetIp,
          errorMessage: err,
        );
      }
    } catch (e) {
      return StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'ICMP probe exception: $e',
      );
    }
  }
}
