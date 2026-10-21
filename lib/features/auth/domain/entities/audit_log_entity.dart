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

  @override
  List<Object?> get props => [id, userId, username, action, details, timestamp];
}
