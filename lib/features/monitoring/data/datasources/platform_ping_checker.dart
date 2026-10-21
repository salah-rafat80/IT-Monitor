import 'dart:io';
import 'dart:isolate';
import 'package:injectable/injectable.dart';

import '../../domain/entities/check_result.dart';
import '../../domain/services/ping_checker.dart';

class PingParams {
  final int deviceId;
  final String targetIp;
  final Duration timeout;

  PingParams({
    required this.deviceId,
    required this.targetIp,
    required this.timeout,
  });
}

@LazySingleton(as: PingChecker)
class PlatformPingChecker implements PingChecker {
  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final params = PingParams(
      deviceId: deviceId,
      targetIp: targetIp,
      timeout: timeout,
    );
    return Isolate.run(() => _executePing(params));
  }

  static Future<CheckResult> _executePing(PingParams params) async {
    final now = DateTime.now();

    // 1. Target validation
    final targetTrimmed = params.targetIp.trim();
    if (targetTrimmed.isEmpty ||
        InternetAddress.tryParse(targetTrimmed) == null) {
      return CheckResult.failure(
        deviceId: params.deviceId,
        targetIp: params.targetIp,
        timestamp: now,
        errorMessage: 'Invalid target IP address: "${params.targetIp}"',
        failureReason: PingFailureReason.invalidTarget,
      );
    }

    try {
      final List<String> arguments = [];
      if (Platform.isWindows) {
        arguments.addAll([
          '-n',
          '1',
          '-w',
          '${params.timeout.inMilliseconds}',
          targetTrimmed,
        ]);
      } else {
        arguments.addAll([
          '-c',
          '1',
          '-W',
          '${params.timeout.inSeconds}',
          targetTrimmed,
        ]);
      }

      final processResult =
          await Process.run('ping', arguments, runInShell: true).timeout(
            params.timeout + const Duration(seconds: 1),
            onTimeout: () =>
                ProcessResult(-1, -1, '', 'Ping process execution timeout'),
          );

      final stdout = processResult.stdout.toString();
      final stderr = processResult.stderr.toString();

      final parsed = parsePingOutput(
        stdout: stdout,
        stderr: stderr,
        exitCode: processResult.exitCode,
        targetIp: targetTrimmed,
      );

      if (parsed.isSuccess) {
        return CheckResult.success(
          deviceId: params.deviceId,
          targetIp: targetTrimmed,
          timestamp: now,
          latencyMs: parsed.latencyMs,
          isSubMillisecond: parsed.isSubMillisecond,
          respondingSourceIp: parsed.respondingSourceIp ?? targetTrimmed,
        );
      } else {
        return CheckResult.failure(
          deviceId: params.deviceId,
          targetIp: targetTrimmed,
          timestamp: now,
          errorMessage: parsed.errorMessage,
          failureReason: parsed.failureReason,
          respondingSourceIp: parsed.respondingSourceIp,
        );
      }
    } catch (e) {
      // Must NEVER throw unhandled exception into monitoring loop
      return CheckResult.failure(
        deviceId: params.deviceId,
        targetIp: params.targetIp,
        timestamp: now,
        errorMessage: 'Ping execution exception: $e',
        failureReason: PingFailureReason.processOrCheckerFailure,
      );
    }
  }

  /// Public parser helper so it can be thoroughly unit tested across Windows/Linux locales and raw outputs
  static ParsedPingResult parsePingOutput({
    required String stdout,
    required String stderr,
    required int exitCode,
    required String targetIp,
  }) {
    final targetLower = targetIp.toLowerCase().trim();
    final lines = stdout.split(RegExp(r'\r?\n'));

    // Check for explicit successful echo reply line
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final lineLower = line.toLowerCase();

      // Extract responding IP from the reply line to ensure it matches targetIp exactly
      final fromMatch = RegExp(
        r'(?:reply from|الرد من|réponse de|antwort von|ответ от|bytes from|from)\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-fA-F0-9:]+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (fromMatch != null && fromMatch.groupCount >= 1) {
        final respondingHost = fromMatch.group(1)?.toLowerCase().trim();
        if (respondingHost != targetLower) {
          continue; // Responded by another host (e.g., gateway or neighboring host with substring overlap)
        }
      } else {
        // Fallback: check exact IP with boundaries so 192.168.27.6 does not match 192.168.27.64
        final exactIpRegex = RegExp(
          r'(?:^|[\s:])' + RegExp.escape(targetLower) + r'(?:[\s:]|$)',
        );
        if (!exactIpRegex.hasMatch(lineLower)) continue;
      }

      // Must NOT contain error/unreachable keywords on the reply line
      if (lineLower.contains('unreachable') ||
          lineLower.contains('timed out') ||
          lineLower.contains('timeout') ||
          lineLower.contains('failure') ||
          lineLower.contains('failed') ||
          lineLower.contains('error') ||
          lineLower.contains('loss') ||
          lineLower.contains('perte') ||
          lineLower.contains('délai') ||
          lineLower.contains('يتعذر') ||
          lineLower.contains('انتهت')) {
        continue;
      }

      // Must contain TTL (universal across Windows, Linux, macOS for successful ICMP Echo Reply)
      final hasTtl = RegExp(
        r'\bttl[=:]\s*\d+',
        caseSensitive: false,
      ).hasMatch(line);
      // Must contain time/latency token (e.g., time=2ms, time<1ms, temps=2 ms, Zeit=2ms, الوقت=)
      final timeMatch = RegExp(
        r'(?:time|temps|zeit|время|الوقت)[=<:]\s*([0-9.]+)\s*(?:ms|мс)?',
        caseSensitive: false,
      ).firstMatch(line);
      final hasLessThanOneMs = RegExp(
        r'(?:time|temps|zeit|الوقت)\s*<\s*1\s*ms',
        caseSensitive: false,
      ).hasMatch(line);

      if (hasTtl && (timeMatch != null || hasLessThanOneMs)) {
        // Confirmed valid Echo Reply from intended target
        int? latency;
        bool isSubMs = false;
        if (hasLessThanOneMs) {
          latency = 1;
          isSubMs = true;
        } else if (timeMatch != null && timeMatch.groupCount >= 1) {
          final parsedNum = double.tryParse(timeMatch.group(1)!);
          if (parsedNum != null) {
            if (parsedNum < 1.0) {
              latency = 1;
              isSubMs = true;
            } else {
              latency = parsedNum.round();
              if (latency <= 0) latency = 1;
            }
          }
        }

        return ParsedPingResult(
          isSuccess: true,
          latencyMs: latency,
          isSubMillisecond: isSubMs,
          failureReason: PingFailureReason.none,
          respondingSourceIp: targetLower,
          errorMessage: '',
        );
      }
    }

    // If we reach here, there was NO confirmed Echo Reply from the requested target.
    // Latency MUST be null on failed checks.
    final combinedLower = '$stdout\n$stderr'.toLowerCase();

    // Check if another IP responded with an ICMP error (e.g. "Reply from 192.168.27.64: Destination host unreachable")
    String? respondingIp;
    final otherReplyMatch = RegExp(
      r'(?:reply from|الرد من|réponse de|antwort von|ответ от|from)\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-fA-F0-9:]+)',
      caseSensitive: false,
    ).firstMatch(stdout);

    if (otherReplyMatch != null && otherReplyMatch.groupCount >= 1) {
      final foundIp = otherReplyMatch.group(1);
      if (foundIp != null && foundIp.toLowerCase() != targetLower) {
        respondingIp = foundIp;
      }
    }

    PingFailureReason reason;
    String errMsg;

    if (respondingIp != null) {
      if (combinedLower.contains('unreachable') ||
          combinedLower.contains('يتعذر')) {
        reason = PingFailureReason.destinationUnreachable;
        errMsg = 'Destination unreachable (responded by $respondingIp)';
      } else {
        reason = PingFailureReason.wrongSourceIp;
        errMsg = 'Received ICMP response from unexpected host: $respondingIp';
      }
    } else if (combinedLower.contains('general failure') ||
        combinedLower.contains('transmit failed') ||
        combinedLower.contains('hardware error') ||
        combinedLower.contains('فشل عام')) {
      reason = PingFailureReason.generalNetworkFailure;
      errMsg = 'General network failure';
    } else if (combinedLower.contains('destination host unreachable') ||
        combinedLower.contains('destination net unreachable') ||
        combinedLower.contains('destination port unreachable') ||
        combinedLower.contains('unreachable') ||
        combinedLower.contains('يتعذر الوصول')) {
      reason = PingFailureReason.destinationUnreachable;
      errMsg = 'Destination host unreachable';
    } else if (combinedLower.contains('timed out') ||
        combinedLower.contains('timeout') ||
        combinedLower.contains('100% loss') ||
        combinedLower.contains('100% packet loss') ||
        combinedLower.contains('انتهت المهلة') ||
        combinedLower.contains('délai d\'attente')) {
      reason = PingFailureReason.timeout;
      errMsg = 'Request timed out';
    } else if (exitCode != 0) {
      reason = PingFailureReason.timeout;
      errMsg = stderr.trim().isNotEmpty
          ? stderr.trim()
          : (stdout.trim().isNotEmpty
                ? stdout.trim()
                : 'Ping failed or timed out');
    } else {
      reason = PingFailureReason.unrecognizedResponse;
      errMsg = stdout.trim().isNotEmpty
          ? stdout.trim()
          : 'Unrecognized ICMP response';
    }

    return ParsedPingResult(
      isSuccess: false,
      latencyMs: null,
      failureReason: reason,
      respondingSourceIp: respondingIp,
      errorMessage: errMsg,
    );
  }
}

class ParsedPingResult {
  final bool isSuccess;
  final int? latencyMs;
  final bool isSubMillisecond;
  final PingFailureReason failureReason;
  final String? respondingSourceIp;
  final String errorMessage;

  const ParsedPingResult({
    required this.isSuccess,
    this.latencyMs,
    this.isSubMillisecond = false,
    required this.failureReason,
    this.respondingSourceIp,
    required this.errorMessage,
  });
}
