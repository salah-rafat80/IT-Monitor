import 'package:equatable/equatable.dart';

class AuditLogEntity extends Equatable {
  final int id;
  final int? userId;
  final String username;
  final String action;
  final String? details;
  final DateTime timestamp;

  const AuditLogEntity({
    required this.id,
    this.userId,
    required this.username,
    required this.action,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'username': username,
    'action': action,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AuditLogEntity.fromJson(Map<String, dynamic> json) {
    return AuditLogEntity(
      id: json['id'] as int? ?? 0,
      userId: json['userId'] as int?,
      username: json['username']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      details: json['details']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, userId, username, action, details, timestamp];
}
