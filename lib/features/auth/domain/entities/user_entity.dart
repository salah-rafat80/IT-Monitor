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

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'role': role.toValue(),
    'isEnabled': isEnabled,
    'createdAt': createdAt.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as int? ?? 0,
      username: json['username']?.toString() ?? '',
      role: UserRole.fromString(json['role']?.toString() ?? 'viewer'),
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
    );
  }

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
