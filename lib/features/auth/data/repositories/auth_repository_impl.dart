import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/password_hash.dart';
import '../../../../core/utils/result.dart';
import '../../../users/domain/repositories/audit_log_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  static final UserEntity localAdminUser = UserEntity(
    id: 1,
    username: 'Local Administrator (No Interactive Login)',
    role: UserRole.admin,
    isEnabled: true,
    createdAt: DateTime(2026, 1, 1),
    lastLoginAt: DateTime.now(),
  );

  final AppDatabase _db;
  final AuditLogRepository _auditLogRepo;
  UserEntity? _currentUser;

  AuthRepositoryImpl(this._db, this._auditLogRepo);

  @override
  Future<Result<bool>> hasAdminAccount() async {
    try {
      final query = _db.select(_db.users)..where((t) => t.role.equals('admin'));
      final adminUsers = await query.get();
      return Result.success(adminUsers.isNotEmpty);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to check admin account: $e'),
      );
    }
  }

  @override
  Future<Result<UserEntity>> createInitialAdmin({
    required String username,
    required String password,
  }) async {
    try {
      final hasAdminResult = await hasAdminAccount();
      if (hasAdminResult.dataOrNull == true) {
        return Result.failure(
          const ValidationFailure('An administrator account already exists.'),
        );
      }

      final hash = PasswordHash.hashPassword(password);
      final id = await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              username: username,
              passwordHash: hash,
              role: const Value('admin'),
              isEnabled: const Value(true),
              createdAt: Value(DateTime.now()),
            ),
          );

      final userRow = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(id))).getSingle();
      final user = UserEntity(
        id: userRow.id,
        username: userRow.username,
        role: UserRole.admin,
        isEnabled: userRow.isEnabled,
        createdAt: userRow.createdAt,
      );

      _currentUser = user;

      await _auditLogRepo.recordLog(
        userId: user.id,
        username: user.username,
        action: 'INITIAL_ADMIN_CREATED',
        details: 'Created initial system administrator account.',
      );

      return Result.success(user);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to create initial admin: $e'),
      );
    }
  }

  @override
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
  }) async {
    try {
      final query = _db.select(_db.users)
        ..where((t) => t.username.equals(username));
      final userRow = await query.getSingleOrNull();

      if (userRow == null) {
        return Result.failure(
          const AuthFailure('Invalid username or password.'),
        );
      }

      if (!userRow.isEnabled) {
        return Result.failure(
          const AuthFailure('This user account is disabled.'),
        );
      }

      final isPasswordValid = PasswordHash.verifyPassword(
        password,
        userRow.passwordHash,
      );
      if (!isPasswordValid) {
        await _auditLogRepo.recordLog(
          userId: userRow.id,
          username: username,
          action: 'LOGIN_FAILED',
          details: 'Incorrect password attempt.',
        );
        return Result.failure(
          const AuthFailure('Invalid username or password.'),
        );
      }

      final now = DateTime.now();
      if (PasswordHash.needsRehash(userRow.passwordHash)) {
        final upgradedHash = PasswordHash.hashPassword(password);
        await (_db.update(
          _db.users,
        )..where((t) => t.id.equals(userRow.id))).write(
          UsersCompanion(
            lastLoginAt: Value(now),
            passwordHash: Value(upgradedHash),
          ),
        );
      } else {
        await (_db.update(_db.users)..where((t) => t.id.equals(userRow.id)))
            .write(UsersCompanion(lastLoginAt: Value(now)));
      }

      final user = UserEntity(
        id: userRow.id,
        username: userRow.username,
        role: UserRole.fromString(userRow.role),
        isEnabled: userRow.isEnabled,
        createdAt: userRow.createdAt,
        lastLoginAt: now,
      );

      _currentUser = user;

      await _auditLogRepo.recordLog(
        userId: user.id,
        username: user.username,
        action: 'LOGIN_SUCCESS',
        details: 'User logged in successfully.',
      );

      return Result.success(user);
    } catch (e) {
      return Result.failure(DatabaseFailure('Login failed: $e'));
    }
  }

  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    return Result.success(_currentUser);
  }

  @override
  Future<Result<void>> logout() async {
    if (_currentUser != null) {
      await _auditLogRepo.recordLog(
        userId: _currentUser!.id,
        username: _currentUser!.username,
        action: 'LOGOUT',
        details: 'User logged out; reverting to local administrator mode.',
      );
    }
    _currentUser = null;
    return Result.success(null);
  }
}
