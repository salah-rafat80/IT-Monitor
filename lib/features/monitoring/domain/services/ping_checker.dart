import '../entities/check_result.dart';

abstract class PingChecker {
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  });
}
