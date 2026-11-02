import 'package:equatable/equatable.dart';

enum GatewayHealthStatus { online, degraded, down, unknown }

/// Represents the first-class operational health state of a factory gateway.
class GatewayStatusEntity extends Equatable {
  final String factoryId;
  final String gatewayIp;
  final GatewayHealthStatus status;
  final DateTime? lastCheckAt;
  final DateTime? lastSuccessfulCheckAt;
  final int? latencyMs;
  final int consecutiveFailures;
  final int consecutiveSuccesses;
  final String? failureReason;

  const GatewayStatusEntity({
    required this.factoryId,
    required this.gatewayIp,
    this.status = GatewayHealthStatus.unknown,
    this.lastCheckAt,
    this.lastSuccessfulCheckAt,
    this.latencyMs,
    this.consecutiveFailures = 0,
    this.consecutiveSuccesses = 0,
    this.failureReason,
  });

  bool get isOnline => status == GatewayHealthStatus.online;
  bool get isDegraded => status == GatewayHealthStatus.degraded;
  bool get isDown => status == GatewayHealthStatus.down;

  GatewayStatusEntity copyWith({
    String? factoryId,
    String? gatewayIp,
    GatewayHealthStatus? status,
    DateTime? lastCheckAt,
    DateTime? lastSuccessfulCheckAt,
    int? latencyMs,
    int? consecutiveFailures,
    int? consecutiveSuccesses,
    String? failureReason,
  }) {
    return GatewayStatusEntity(
      factoryId: factoryId ?? this.factoryId,
      gatewayIp: gatewayIp ?? this.gatewayIp,
      status: status ?? this.status,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      lastSuccessfulCheckAt:
          lastSuccessfulCheckAt ?? this.lastSuccessfulCheckAt,
      latencyMs: latencyMs ?? this.latencyMs,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  Map<String, dynamic> toJson() => {
    'factoryId': factoryId,
    'gatewayIp': gatewayIp,
    'status': status.name,
    'lastCheckAt': lastCheckAt?.toIso8601String(),
    'lastSuccessfulCheckAt': lastSuccessfulCheckAt?.toIso8601String(),
    'latencyMs': latencyMs,
    'consecutiveFailures': consecutiveFailures,
    'consecutiveSuccesses': consecutiveSuccesses,
    'failureReason': failureReason,
  };

  factory GatewayStatusEntity.fromJson(Map<String, dynamic> json) {
    return GatewayStatusEntity(
      factoryId: json['factoryId'] as String? ?? '',
      gatewayIp: json['gatewayIp'] as String? ?? '',
      status: GatewayHealthStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GatewayHealthStatus.unknown,
      ),
      lastCheckAt: DateTime.tryParse(json['lastCheckAt'] as String? ?? ''),
      lastSuccessfulCheckAt: DateTime.tryParse(
        json['lastSuccessfulCheckAt'] as String? ?? '',
      ),
      latencyMs: json['latencyMs'] as int?,
      consecutiveFailures: json['consecutiveFailures'] as int? ?? 0,
      consecutiveSuccesses: json['consecutiveSuccesses'] as int? ?? 0,
      failureReason: json['failureReason'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    factoryId,
    gatewayIp,
    status,
    lastCheckAt,
    lastSuccessfulCheckAt,
    latencyMs,
    consecutiveFailures,
    consecutiveSuccesses,
    failureReason,
  ];
}
