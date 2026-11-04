import '../entities/check_result.dart';
import '../entities/device_status_entity.dart';
import '../entities/monitoring_config.dart';

class StatusEngine {
  static DeviceStatusEntity processCheckResult({
    required DeviceStatusEntity currentStatus,
    required CheckResult checkResult,
    required MonitoringConfig config,
  }) {
    final now = checkResult.timestamp;

    // Maintenance Mode Check
    if (currentStatus.isMaintenance) {
      return currentStatus.copyWith(
        lastCheckAt: now,
        lastSeen: checkResult.isSuccess ? now : currentStatus.lastSeen,
        lastLatencyMs: checkResult.isSuccess ? checkResult.latencyMs : null,
        clearLastLatency: !checkResult.isSuccess,
        lastSuccessfulLatencyMs: checkResult.isSuccess
            ? (checkResult.latencyMs ?? currentStatus.lastSuccessfulLatencyMs)
            : currentStatus.lastSuccessfulLatencyMs,
        lastFailureReason: checkResult.isSuccess
            ? null
            : (checkResult.errorMessage ??
                  checkResult.failureReason.displayName),
        clearFailureReason: checkResult.isSuccess,
        status: DeviceStatusEnum.maintenance,
      );
    }

    if (checkResult.isSuccess) {
      final newSuccesses = currentStatus.consecutiveSuccesses + 1;
      final newFailures = 0; // Success resets failure streak

      DeviceStatusEnum newStatus = currentStatus.status;
      DateTime statusChangedAt = currentStatus.statusChangedAt;

      if (currentStatus.status == DeviceStatusEnum.down) {
        // Recovery logic: must reach recoveryThreshold (e.g. 2) consecutive successes
        if (newSuccesses >= config.recoveryThreshold) {
          newStatus = DeviceStatusEnum.up;
          statusChangedAt = now;
        }
      } else {
        // Evaluate Degraded vs Up
        if (config.degradedLatencyThresholdMs != null &&
            checkResult.latencyMs != null &&
            checkResult.latencyMs! > config.degradedLatencyThresholdMs!) {
          newStatus = DeviceStatusEnum.degraded;
        } else {
          newStatus = DeviceStatusEnum.up;
        }

        if (currentStatus.status != newStatus) {
          statusChangedAt = now;
        }
      }

      return currentStatus.copyWith(
        status: newStatus,
        lastSeen: now,
        lastCheckAt: now,
        lastLatencyMs: checkResult.latencyMs,
        isSubMillisecond: checkResult.isSubMillisecond,
        lastSuccessfulLatencyMs:
            checkResult.latencyMs ?? currentStatus.lastSuccessfulLatencyMs,
        clearFailureReason: true,
        consecutiveFailures: newFailures,
        consecutiveSuccesses: newSuccesses,
        statusChangedAt: statusChangedAt,
        hasInternet: checkResult.hasInternet ?? true,
        failureThreshold: config.failureThreshold,
      );
    } else {
      // Failure Check
      final newFailures = currentStatus.consecutiveFailures + 1;
      final newSuccesses = 0; // Failure resets recovery streak

      DeviceStatusEnum newStatus = currentStatus.status;
      DateTime statusChangedAt = currentStatus.statusChangedAt;

      if (currentStatus.status != DeviceStatusEnum.down) {
        // Down logic: must reach failureThreshold (e.g. 3) consecutive failures
        if (newFailures >= config.failureThreshold) {
          newStatus = DeviceStatusEnum.down;
          statusChangedAt = now;
        }
      }

      return currentStatus.copyWith(
        status: newStatus,
        lastCheckAt: now,
        clearLastLatency: true, // Current check latency MUST be null on failure
        lastSuccessfulLatencyMs: currentStatus
            .lastSuccessfulLatencyMs, // Historical latency preserved
        lastFailureReason:
            checkResult.errorMessage ?? checkResult.failureReason.displayName,
        consecutiveFailures: newFailures,
        consecutiveSuccesses: newSuccesses,
        statusChangedAt: statusChangedAt,
        hasInternet: false,
        failureThreshold: config.failureThreshold,
      );
    }
  }
}
