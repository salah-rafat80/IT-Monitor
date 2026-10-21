import 'package:equatable/equatable.dart';

class MonitoringConfig extends Equatable {
  final int checkIntervalSeconds;
  final int timeoutSeconds;
  final int failureThreshold;
  final int recoveryThreshold;
  final int? degradedLatencyThresholdMs;
  final int maxConcurrentChecks;

  const MonitoringConfig({
    this.checkIntervalSeconds = 60,
    this.timeoutSeconds = 3,
    this.failureThreshold = 3,
    this.recoveryThreshold = 1,
    this.degradedLatencyThresholdMs,
    this.maxConcurrentChecks = 50,
  });

  @override
  List<Object?> get props => [
    checkIntervalSeconds,
    timeoutSeconds,
    failureThreshold,
    recoveryThreshold,
    degradedLatencyThresholdMs,
    maxConcurrentChecks,
  ];
}
