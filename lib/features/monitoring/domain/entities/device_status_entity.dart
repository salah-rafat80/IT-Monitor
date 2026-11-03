import 'package:equatable/equatable.dart';

enum DeviceStatusEnum {
  unknown,
  up,
  degraded,
  down,
  unreachable,
  maintenance,
  stale;

  static DeviceStatusEnum fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'up':
      case 'connected':
      case 'online':
        return DeviceStatusEnum.up;
      case 'degraded':
        return DeviceStatusEnum.degraded;
      case 'down':
      case 'disconnected':
      case 'offline':
        return DeviceStatusEnum.down;
      case 'unreachable':
        return DeviceStatusEnum.unreachable;
      case 'maintenance':
        return DeviceStatusEnum.maintenance;
      case 'stale':
        return DeviceStatusEnum.stale;
      default:
        return DeviceStatusEnum.unknown;
    }
  }

  String toValue() => name;

  String get displayName {
    switch (this) {
      case DeviceStatusEnum.up:
        return 'Online';
      case DeviceStatusEnum.degraded:
        return 'Degraded';
      case DeviceStatusEnum.down:
        return 'Offline';
      case DeviceStatusEnum.unreachable:
        return 'Unreachable';
      case DeviceStatusEnum.maintenance:
        return 'Maintenance';
      case DeviceStatusEnum.stale:
        return 'Stale';
      case DeviceStatusEnum.unknown:
        return 'Unknown';
    }
  }
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

  /// Standard freshness limit window: 180 seconds (3 minutes / 3 intervals).
  static const int defaultFreshnessWindowSeconds = 180;

  bool isStale({DateTime? now, int? freshnessWindowSeconds}) {
    if (lastCheckAt == null) return false;
    final current = now ?? DateTime.now();
    final window = freshnessWindowSeconds ?? defaultFreshnessWindowSeconds;
    return current.difference(lastCheckAt!).inSeconds > window;
  }

  DeviceStatusEnum effectiveStatus({
    DateTime? now,
    int? freshnessWindowSeconds,
  }) {
    if (lastCheckAt == null) {
      return DeviceStatusEnum.unknown;
    }
    if (isMaintenance) {
      return DeviceStatusEnum.maintenance;
    }
    if (isStale(now: now, freshnessWindowSeconds: freshnessWindowSeconds)) {
      return DeviceStatusEnum.stale;
    }
    return status;
  }

  /// True when the device is currently retained as UP/Online by threshold policy,
  /// but has recent consecutive probe failures (1 or 2 failures below failureThreshold).
  bool get isTransitionalFailing =>
      status == DeviceStatusEnum.up && consecutiveFailures > 0;

  /// Clear transitional human-readable label when failing below threshold.
  String get transitionalLabel {
    if (isTransitionalFailing) {
      return 'Previously Online · $consecutiveFailures/3 Failed Checks';
    }
    return effectiveStatus().displayName;
  }

  String get freshnessDescription {
    if (lastCheckAt == null) return 'Never checked';
    final diff = DateTime.now().difference(lastCheckAt!);
    if (diff.inSeconds < 60) return 'Fresh (${diff.inSeconds}s ago)';
    if (diff.inMinutes < 60) return 'Recent (${diff.inMinutes}m ago)';
    if (diff.inHours < 24) return 'Stale (${diff.inHours}h ago)';
    return 'Stale (${diff.inDays}d ago)';
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

  factory DeviceStatusEntity.fromJson(Map<String, dynamic> json) {
    return DeviceStatusEntity(
      deviceId: json['deviceId'] is int
          ? json['deviceId'] as int
          : int.tryParse(json['deviceId']?.toString() ?? '0') ?? 0,
      status: DeviceStatusEnum.fromString(
        json['status']?.toString() ?? 'unknown',
      ),
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'].toString())
          : null,
      lastCheckAt: json['lastCheckAt'] != null
          ? DateTime.tryParse(json['lastCheckAt'].toString())
          : null,
      lastLatencyMs: json['lastLatencyMs'] as int?,
      lastSuccessfulLatencyMs: json['lastSuccessfulLatencyMs'] as int?,
      lastFailureReason: json['lastFailureReason']?.toString(),
      consecutiveFailures: json['consecutiveFailures'] is int
          ? json['consecutiveFailures'] as int
          : int.tryParse(json['consecutiveFailures']?.toString() ?? '0') ?? 0,
      consecutiveSuccesses: json['consecutiveSuccesses'] is int
          ? json['consecutiveSuccesses'] as int
          : int.tryParse(json['consecutiveSuccesses']?.toString() ?? '0') ?? 0,
      statusChangedAt: json['statusChangedAt'] != null
          ? DateTime.tryParse(json['statusChangedAt'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      isMaintenance: json['isMaintenance'] == true,
      hasInternet: json['hasInternet'] != false,
      isSubMillisecond: json['isSubMillisecond'] == true,
    );
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
