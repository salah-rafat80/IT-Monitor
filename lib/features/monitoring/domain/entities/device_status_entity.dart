import 'package:equatable/equatable.dart';

enum DeviceStatusEnum {
  unknown,
  up,
  degraded,
  down,
  unreachable,
  maintenance;

  static DeviceStatusEnum fromString(String value) {
    switch (value.toLowerCase()) {
      case 'up':
        return DeviceStatusEnum.up;
      case 'degraded':
        return DeviceStatusEnum.degraded;
      case 'down':
        return DeviceStatusEnum.down;
      case 'unreachable':
        return DeviceStatusEnum.unreachable;
      case 'maintenance':
        return DeviceStatusEnum.maintenance;
      default:
        return DeviceStatusEnum.unknown;
    }
  }

  String toValue() => name;
}

class DeviceStatusEntity extends Equatable {
  final int deviceId;
  final DeviceStatusEnum status;
  final DateTime? lastSeen;
  final DateTime? lastCheckAt;
  final int? lastLatencyMs; // Current check latency (null when check failed)
  final int?
  lastSuccessfulLatencyMs; // Historical latency from last successful check
  final String?
  lastFailureReason; // Diagnostics: reason of latest check failure
  final int consecutiveFailures;
  final int consecutiveSuccesses;
  final DateTime statusChangedAt;
  final bool isMaintenance;
  final bool hasInternet;
  final bool isSubMillisecond;

  const DeviceStatusEntity({
    required this.deviceId,
    this.status = DeviceStatusEnum.unknown,
    this.lastSeen,
    this.lastCheckAt,
    this.lastLatencyMs,
    this.lastSuccessfulLatencyMs,
    this.lastFailureReason,
    this.consecutiveFailures = 0,
    this.consecutiveSuccesses = 0,
    required this.statusChangedAt,
    this.isMaintenance = false,
    this.hasInternet = true,
    this.isSubMillisecond = false,
  });

  factory DeviceStatusEntity.initial(int deviceId) {
    return DeviceStatusEntity(
      deviceId: deviceId,
      status: DeviceStatusEnum.unknown,
      statusChangedAt: DateTime.now(),
      hasInternet: false,
    );
  }

  String get displayLatency {
    if (lastLatencyMs == null) return '-';
    if (isSubMillisecond) return '≤1 ms';
    return '$lastLatencyMs ms';
  }

  DeviceStatusEntity copyWith({
    int? deviceId,
    DeviceStatusEnum? status,
    DateTime? lastSeen,
    DateTime? lastCheckAt,
    int? lastLatencyMs,
    bool clearLastLatency = false,
    int? lastSuccessfulLatencyMs,
    String? lastFailureReason,
    bool clearFailureReason = false,
    int? consecutiveFailures,
    int? consecutiveSuccesses,
    DateTime? statusChangedAt,
    bool? isMaintenance,
    bool? hasInternet,
    bool? isSubMillisecond,
  }) {
    return DeviceStatusEntity(
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      lastLatencyMs: clearLastLatency
          ? null
          : (lastLatencyMs ?? this.lastLatencyMs),
      lastSuccessfulLatencyMs:
          lastSuccessfulLatencyMs ?? this.lastSuccessfulLatencyMs,
      lastFailureReason: clearFailureReason
          ? null
          : (lastFailureReason ?? this.lastFailureReason),
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      isMaintenance: isMaintenance ?? this.isMaintenance,
      hasInternet: hasInternet ?? this.hasInternet,
      isSubMillisecond:
          isSubMillisecond ??
          (clearLastLatency ? false : this.isSubMillisecond),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'status': status.name,
      'lastSeen': lastSeen?.toIso8601String(),
      'lastCheckAt': lastCheckAt?.toIso8601String(),
      'lastLatencyMs': lastLatencyMs,
      'lastSuccessfulLatencyMs': lastSuccessfulLatencyMs,
      'lastFailureReason': lastFailureReason,
      'consecutiveFailures': consecutiveFailures,
      'consecutiveSuccesses': consecutiveSuccesses,
      'statusChangedAt': statusChangedAt.toIso8601String(),
      'isMaintenance': isMaintenance,
      'hasInternet': hasInternet,
      'isSubMillisecond': isSubMillisecond,
    };
  }

  @override
  List<Object?> get props => [
    deviceId,
    status,
    lastSeen,
    lastCheckAt,
    lastLatencyMs,
    lastSuccessfulLatencyMs,
    lastFailureReason,
    consecutiveFailures,
    consecutiveSuccesses,
    statusChangedAt,
    isMaintenance,
    hasInternet,
    isSubMillisecond,
  ];
}
