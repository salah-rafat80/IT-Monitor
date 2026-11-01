import 'package:equatable/equatable.dart';

enum CheckType {
  icmp;

  static CheckType fromString(String value) {
    return value.toLowerCase() == 'icmp' ? CheckType.icmp : CheckType.icmp;
  }

  String toValue() => name;
}

enum PingFailureReason {
  none,
  timeout,
  destinationUnreachable,
  wrongSourceIp,
  generalNetworkFailure,
  invalidTarget,
  processOrCheckerFailure,
  unrecognizedResponse;

  String get displayName {
    switch (this) {
      case PingFailureReason.none:
        return 'Success';
      case PingFailureReason.timeout:
        return 'Request Timed Out';
      case PingFailureReason.destinationUnreachable:
        return 'Destination Host Unreachable';
      case PingFailureReason.wrongSourceIp:
        return 'Response from Unexpected Source';
      case PingFailureReason.generalNetworkFailure:
        return 'General Network Failure';
      case PingFailureReason.invalidTarget:
        return 'Invalid Target IP';
      case PingFailureReason.processOrCheckerFailure:
        return 'Ping Process Execution Failure';
      case PingFailureReason.unrecognizedResponse:
        return 'Unrecognized ICMP Response';
    }
  }
}

class CheckResult extends Equatable {
  final int deviceId;
  final String? assetId;
  final String? factoryId;
  final String targetIp;
  final CheckType checkType;
  final DateTime timestamp;
  final bool isSuccess;
  final int? latencyMs;
  final double? packetLossPercent;
  final String? errorMessage;
  final bool? hasInternet;
  final PingFailureReason failureReason;
  final String? respondingSourceIp;
  final bool isSubMillisecond;

  const CheckResult({
    required this.deviceId,
    String? assetId,
    this.factoryId,
    required this.targetIp,
    this.checkType = CheckType.icmp,
    required this.timestamp,
    required this.isSuccess,
    this.latencyMs,
    this.packetLossPercent,
    this.errorMessage,
    this.hasInternet,
    this.failureReason = PingFailureReason.none,
    this.respondingSourceIp,
    this.isSubMillisecond = false,
  }) : assetId =
           assetId ??
           (deviceId >= 10000
               ? 'infra:${deviceId - 10000}'
               : (deviceId > 0 ? 'device:$deviceId' : null));

  factory CheckResult.success({
    required int deviceId,
    String? assetId,
    String? factoryId,
    required String targetIp,
    required DateTime timestamp,
    int? latencyMs,
    double? packetLossPercent,
    bool? hasInternet = true,
    String? respondingSourceIp,
    bool isSubMillisecond = false,
  }) {
    return CheckResult(
      deviceId: deviceId,
      assetId: assetId,
      factoryId: factoryId,
      targetIp: targetIp,
      timestamp: timestamp,
      isSuccess: true,
      latencyMs: latencyMs,
      packetLossPercent: packetLossPercent,
      hasInternet: hasInternet,
      failureReason: PingFailureReason.none,
      respondingSourceIp: respondingSourceIp ?? targetIp,
      isSubMillisecond: isSubMillisecond,
    );
  }

  factory CheckResult.failure({
    required int deviceId,
    String? assetId,
    String? factoryId,
    required String targetIp,
    required DateTime timestamp,
    required String errorMessage,
    bool? hasInternet = false,
    PingFailureReason failureReason = PingFailureReason.unrecognizedResponse,
    String? respondingSourceIp,
  }) {
    return CheckResult(
      deviceId: deviceId,
      assetId: assetId,
      factoryId: factoryId,
      targetIp: targetIp,
      timestamp: timestamp,
      isSuccess: false,
      errorMessage: errorMessage,
      hasInternet: hasInternet ?? false,
      failureReason: failureReason,
      respondingSourceIp: respondingSourceIp,
      isSubMillisecond: false,
    );
  }

  @override
  List<Object?> get props => [
    deviceId,
    assetId,
    factoryId,
    targetIp,
    checkType,
    timestamp,
    isSuccess,
    latencyMs,
    packetLossPercent,
    errorMessage,
    hasInternet,
    failureReason,
    respondingSourceIp,
    isSubMillisecond,
  ];
}
