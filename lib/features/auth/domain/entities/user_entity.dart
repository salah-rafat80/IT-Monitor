import 'package:equatable/equatable.dart';

enum UserRole {
  admin,
  viewer;

  static UserRole fromString(String value) {
    return value.toLowerCase() == 'admin' ? UserRole.admin : UserRole.viewer;
  }

  String toValue() => name;
}

class UserEntity extends Equatable {
  final int id;
  final String username;
  final UserRole role;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserEntity({
    required this.id,
    required this.username,
    required this.role,
    required this.isEnabled,
    required this.createdAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isViewer => role == UserRole.viewer;

  @override
  List<Object?> get props => [
    id,
    username,
    role,
    isEnabled,
    createdAt,
    lastLoginAt,
  ];
}
