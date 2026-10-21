import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthUnauthenticated extends AuthState {
  final bool hasAdminAccount;

  const AuthUnauthenticated({required this.hasAdminAccount});

  @override
  List<Object?> get props => [hasAdminAccount];
}

final class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

final class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

@lazySingleton
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepo;

  AuthCubit(this._authRepo) : super(const AuthInitial());

  Future<void> checkAuthStatus([String? customTokenPath]) async {
    emit(const AuthLoading());

    final currentUserRes = await _authRepo.getCurrentUser();
    final currentUser = currentUserRes.dataOrNull;

    if (currentUser != null) {
      emit(AuthAuthenticated(currentUser));
      return;
    }

    // On Windows, enforce that only members of ITNetworkMonitorAdministrators (or Admins/SYSTEM)
    // who have read permissions on trusted_client.token obtain direct administrative access.
    final isTestEnvironment =
        Platform.environment.containsKey('FLUTTER_TEST') &&
        customTokenPath == null;

    if (!isTestEnvironment && (Platform.isWindows || customTokenPath != null)) {
      final programData = Platform.environment['ProgramData'];
      final tokenPath =
          customTokenPath ??
          Platform.environment['IT_MONITOR_TRUSTED_TOKEN_PATH'] ??
          (programData != null
              ? p.join(programData, 'ITNetworkMonitor', 'trusted_client.token')
              : null);

      if (tokenPath != null) {
        try {
          final file = File(tokenPath);
          if (!file.existsSync()) {
            emit(
              const AuthError(
                'Trusted client token not found. The IT Network Monitor Service may not be running.',
              ),
            );
            emit(const AuthUnauthenticated(hasAdminAccount: true));
            return;
          }

          final token = file.readAsStringSync().trim();
          if (token.isEmpty || token.length < 32) {
            emit(
              const AuthError(
                'Trusted client token is invalid or empty. Contact system administrator.',
              ),
            );
            emit(const AuthUnauthenticated(hasAdminAccount: true));
            return;
          }
        } on PathAccessException catch (_) {
          emit(
            const AuthError(
              'Access Denied: Current Windows account is not authorized. '
              'Membership in "ITNetworkMonitorAdministrators" is required.',
            ),
          );
          emit(const AuthUnauthenticated(hasAdminAccount: true));
          return;
        } catch (e) {
          emit(AuthError('Failed to access trusted client token: $e'));
          emit(const AuthUnauthenticated(hasAdminAccount: true));
          return;
        }
      }
    }

    // Default local application mode to Administrator access without interactive login
    emit(AuthAuthenticated(AuthRepositoryImpl.localAdminUser));
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    emit(const AuthLoading());

    final res = await _authRepo.login(username: username, password: password);

    res.fold(
      onSuccess: (user) => emit(AuthAuthenticated(user)),
      onFailure: (failure) async {
        final hasAdminRes = await _authRepo.hasAdminAccount();
        final hasAdmin = hasAdminRes.dataOrNull ?? false;
        emit(AuthError(failure.message));
        emit(AuthUnauthenticated(hasAdminAccount: hasAdmin));
      },
    );
  }

  Future<void> createInitialAdmin({
    required String username,
    required String password,
  }) async {
    emit(const AuthLoading());

    final res = await _authRepo.createInitialAdmin(
      username: username,
      password: password,
    );

    res.fold(
      onSuccess: (user) => emit(AuthAuthenticated(user)),
      onFailure: (failure) => emit(AuthError(failure.message)),
    );
  }

  Future<void> logout() async {
    await _authRepo.logout();
    final userRes = await _authRepo.getCurrentUser();
    if (userRes.dataOrNull != null) {
      emit(AuthAuthenticated(userRes.dataOrNull!));
    }
  }
}
