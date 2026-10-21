import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../auth/domain/entities/audit_log_entity.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/repositories/audit_log_repository.dart';
import '../../domain/repositories/user_repository.dart';

sealed class UserManagementState extends Equatable {
  const UserManagementState();

  @override
  List<Object?> get props => [];
}

final class UserManagementInitial extends UserManagementState {
  const UserManagementInitial();
}

final class UserManagementLoading extends UserManagementState {
  const UserManagementLoading();
}

final class UserManagementLoaded extends UserManagementState {
  final List<UserEntity> users;
  final List<AuditLogEntity> auditLogs;

  const UserManagementLoaded({required this.users, required this.auditLogs});

  @override
  List<Object?> get props => [users, auditLogs];
}

final class UserManagementError extends UserManagementState {
  final String message;

  const UserManagementError(this.message);

  @override
  List<Object?> get props => [message];
}

@injectable
class UserManagementCubit extends Cubit<UserManagementState> {
  final UserRepository _userRepo;
  final AuditLogRepository _auditLogRepo;

  UserManagementCubit(this._userRepo, this._auditLogRepo)
    : super(const UserManagementInitial());

  Future<void> loadUsersAndLogs() async {
    emit(const UserManagementLoading());

    final usersRes = await _userRepo.getUsers();
    final logsRes = await _auditLogRepo.getAuditLogs();

    if (usersRes.isFailure) {
      emit(UserManagementError(usersRes.failureOrNull!.message));
      return;
    }

    emit(
      UserManagementLoaded(
        users: usersRes.dataOrNull ?? [],
        auditLogs: logsRes.dataOrNull ?? [],
      ),
    );
  }

  Future<void> createUser({
    required String username,
    required String password,
    required UserRole role,
  }) async {
    final res = await _userRepo.createUser(
      username: username,
      password: password,
      role: role,
    );

    res.fold(
      onSuccess: (_) => loadUsersAndLogs(),
      onFailure: (failure) => emit(UserManagementError(failure.message)),
    );
  }

  Future<void> updateUserRole({
    required int userId,
    required UserRole role,
  }) async {
    final res = await _userRepo.updateUserRole(userId: userId, role: role);

    res.fold(
      onSuccess: (_) => loadUsersAndLogs(),
      onFailure: (failure) => emit(UserManagementError(failure.message)),
    );
  }

  Future<void> toggleUserEnabled({
    required int userId,
    required bool isEnabled,
  }) async {
    final res = await _userRepo.toggleUserEnabled(
      userId: userId,
      isEnabled: isEnabled,
    );

    res.fold(
      onSuccess: (_) => loadUsersAndLogs(),
      onFailure: (failure) => emit(UserManagementError(failure.message)),
    );
  }

  Future<void> resetPassword({
    required int userId,
    required String newPassword,
  }) async {
    final res = await _userRepo.resetUserPassword(
      userId: userId,
      newPassword: newPassword,
    );

    res.fold(
      onSuccess: (_) => loadUsersAndLogs(),
      onFailure: (failure) => emit(UserManagementError(failure.message)),
    );
  }
}
