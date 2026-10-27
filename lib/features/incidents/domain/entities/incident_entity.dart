import 'package:equatable/equatable.dart';

enum IncidentTypeEnum {
  deviceDown,
  highLatency,
  networkDown,
  gatewayDown,
  controllerDown;

  String toValue() {
    switch (this) {
      case IncidentTypeEnum.deviceDown:
        return 'device_down';
      case IncidentTypeEnum.highLatency:
        return 'high_latency';
      case IncidentTypeEnum.networkDown:
        return 'network_down';
      case IncidentTypeEnum.gatewayDown:
        return 'gateway_down';
      case IncidentTypeEnum.controllerDown:
        return 'controller_down';
    }
  }

  static IncidentTypeEnum fromString(String val) {
    switch (val.toLowerCase()) {
      case 'high_latency':
        return IncidentTypeEnum.highLatency;
      case 'network_down':
        return IncidentTypeEnum.networkDown;
      case 'gateway_down':
        return IncidentTypeEnum.gatewayDown;
      case 'controller_down':
        return IncidentTypeEnum.controllerDown;
      case 'device_down':
      default:
        return IncidentTypeEnum.deviceDown;
    }
  }
}

enum IncidentSeverityEnum {
  critical,
  high,
  medium,
  low;

  String toValue() {
    return name;
  }

  static IncidentSeverityEnum fromString(String val) {
    switch (val.toLowerCase()) {
      case 'high':
        return IncidentSeverityEnum.high;
      case 'medium':
        return IncidentSeverityEnum.medium;
      case 'low':
        return IncidentSeverityEnum.low;
      case 'critical':
      default:
        return IncidentSeverityEnum.critical;
    }
  }
}

enum IncidentStatusEnum {
  active,
  acknowledged,
  resolved;

  String toValue() {
    return name;
  }

  static IncidentStatusEnum fromString(String val) {
    switch (val.toLowerCase()) {
      case 'acknowledged':
        return IncidentStatusEnum.acknowledged;
      case 'resolved':
        return IncidentStatusEnum.resolved;
      case 'active':
      default:
        return IncidentStatusEnum.active;
    }
  }
}

class IncidentEntity extends Equatable {
  final int id;
  final String factoryId;
  final int deviceId;
  final String deviceName;
  final String ownerName;
  final String department;
  final String? location;
  final String deviceIp;
  final IncidentTypeEnum incidentType;
  final IncidentSeverityEnum severity;
  final IncidentStatusEnum status;
  final DateTime startedAt;
  final DateTime? resolvedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final String? notes;
  final String? correlationMessage;

  const IncidentEntity({
    required this.id,
    this.factoryId = 'unassigned',
    required this.deviceId,
    required this.deviceName,
    required this.ownerName,
    required this.department,
    this.location,
    required this.deviceIp,
    required this.incidentType,
    required this.severity,
    required this.status,
    required this.startedAt,
    this.resolvedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.notes,
    this.correlationMessage,
  });

  IncidentEntity copyWith({
    int? id,
    String? factoryId,
    int? deviceId,
    String? deviceName,
    String? ownerName,
    String? department,
    String? location,
    String? deviceIp,
    IncidentTypeEnum? incidentType,
    IncidentSeverityEnum? severity,
    IncidentStatusEnum? status,
    DateTime? startedAt,
    DateTime? resolvedAt,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    String? notes,
    String? correlationMessage,
  }) {
    return IncidentEntity(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ownerName: ownerName ?? this.ownerName,
      department: department ?? this.department,
      location: location ?? this.location,
      deviceIp: deviceIp ?? this.deviceIp,
      incidentType: incidentType ?? this.incidentType,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      notes: notes ?? this.notes,
      correlationMessage: correlationMessage ?? this.correlationMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'ownerName': ownerName,
      'department': department,
      'location': location,
      'deviceIp': deviceIp,
      'incidentType': incidentType.name,
      'severity': severity.name,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'acknowledgedBy': acknowledgedBy,
      'notes': notes,
      'correlationMessage': correlationMessage,
    };
  }

  factory IncidentEntity.fromJson(Map<String, dynamic> json) {
    return IncidentEntity(
      id: json['id'] as int? ?? 0,
      factoryId: json['factoryId']?.toString() ?? 'unassigned',
      deviceId: json['deviceId'] as int? ?? 0,
      deviceName: json['deviceName']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? 'Unassigned',
      department: json['department']?.toString() ?? 'General',
      location: json['location']?.toString(),
      deviceIp: json['deviceIp']?.toString() ?? '',
      incidentType: IncidentTypeEnum.fromString(
        json['incidentType']?.toString() ?? 'device_down',
      ),
      severity: IncidentSeverityEnum.fromString(
        json['severity']?.toString() ?? 'critical',
      ),
      status: IncidentStatusEnum.fromString(
        json['status']?.toString() ?? 'active',
      ),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'].toString())
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())
          : null,
      acknowledgedBy: json['acknowledgedBy']?.toString(),
      notes: json['notes']?.toString(),
      correlationMessage: json['correlationMessage']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    factoryId,
    deviceId,
    deviceName,
    ownerName,
    department,
    location,
    deviceIp,
    incidentType,
    severity,
    status,
    startedAt,
    resolvedAt,
    acknowledgedAt,
    acknowledgedBy,
    notes,
    correlationMessage,
  ];
}
