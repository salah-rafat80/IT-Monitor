import 'package:equatable/equatable.dart';

class StrategyProbeResult extends Equatable {
  final String strategyName;
  final String targetIp;
  final bool isSuccess;
  final int? latencyMs;
  final String? mac;
  final String? hostname;
  final List<String> observedServices;
  final String? evidenceDetails;
  final String? errorMessage;
  final DateTime timestamp;

  const StrategyProbeResult({
    required this.strategyName,
    required this.targetIp,
    required this.isSuccess,
    this.latencyMs,
    this.mac,
    this.hostname,
    this.observedServices = const [],
    this.evidenceDetails,
    this.errorMessage,
    required this.timestamp,
  });

  factory StrategyProbeResult.success({
    required String strategyName,
    required String targetIp,
    int? latencyMs,
    String? mac,
    String? hostname,
    List<String> observedServices = const [],
    String? evidenceDetails,
  }) {
    return StrategyProbeResult(
      strategyName: strategyName,
      targetIp: targetIp,
      isSuccess: true,
      latencyMs: latencyMs,
      mac: mac,
      hostname: hostname,
      observedServices: observedServices,
      evidenceDetails: evidenceDetails,
      timestamp: DateTime.now(),
    );
  }

  factory StrategyProbeResult.failure({
    required String strategyName,
    required String targetIp,
    required String errorMessage,
  }) {
    return StrategyProbeResult(
      strategyName: strategyName,
      targetIp: targetIp,
      isSuccess: false,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    strategyName,
    targetIp,
    isSuccess,
    latencyMs,
    mac,
    hostname,
    observedServices,
    evidenceDetails,
    errorMessage,
    timestamp,
  ];
}

abstract class DiscoveryStrategy {
  String get name;

  /// Probes an individual target IP address with a bounded timeout duration.
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout);
}
