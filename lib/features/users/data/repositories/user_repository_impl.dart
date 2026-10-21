import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/password_hash.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/audit_log_repository.dart';
import '../../domain/repositories/user_repository.dart';

@LazySingleton(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  final AppDatabase _db;
  final AuditLogRepository _auditLogRepo;
  final AuthRepository _authRepo;

  UserRepositoryImpl(this._db, this._auditLogRepo, this._authRepo);

  Future<UserEntity?> _getActiveActor() async {
    final res = await _authRepo.getCurrentUser();
    return res.dataOrNull;
  }

  @override
  Future<Result<List<UserEntity>>> getUsers() async {
    try {
      final rows = await _db.select(_db.users).get();
      final users = rows
          .map(
            (row) => UserEntity(
              id: row.id,
              username: row.username,
              role: UserRole.fromString(row.role),
              isEnabled: row.isEnabled,
              createdAt: row.createdAt,
              lastLoginAt: row.lastLoginAt,
            ),
          )
          .toList();
      return Result.success(users);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to load users: $e'));
    }
  }

  @override
  Future<Result<UserEntity>> createUser({
    required String username,
    required String password,
    required UserRole role,
  }) async {
    try {
      final actor = await _getActiveActor();
      if (actor == null || !actor.isAdmin) {
        return Result.failure(
          const UnauthorizedFailure('Only administrators can create users.'),
        );
      }

      final existing = await (_db.select(
        _db.users,
      )..where((t) => t.username.equals(username))).getSingleOrNull();
      if (existing != null) {
        return Result.failure(
          const ValidationFailure('Username already exists.'),
        );
      }

      final hash = PasswordHash.hashPassword(password);
      final id = await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              username: username,
              passwordHash: hash,
              role: Value(role.toValue()),
              isEnabled: const Value(true),
              createdAt: Value(DateTime.now()),
            ),
          );

      final row = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(id))).getSingle();
      final createdUser = UserEntity(
        id: row.id,
        username: row.username,
        role: UserRole.fromString(row.role),
        isEnabled: row.isEnabled,
        createdAt: row.createdAt,
      );

      await _auditLogRepo.recordLog(
        userId: actor.id,
        username: actor.username,
        action: 'USER_CREATED',
        details: 'Created user ${createdUser.username} with role ${role.name}.',
      );

      return Result.success(createdUser);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to create user: $e'));
    }
  }

  @override
  Future<Result<UserEntity>> updateUserRole({
    required int userId,
    required UserRole role,
  }) async {
    try {
      final actor = await _getActiveActor();
      if (actor == null || !actor.isAdmin) {
        return Result.failure(
          const UnauthorizedFailure(
            'Only administrators can update user roles.',
          ),
        );
      }

      final userRow = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (userRow == null) {
        return Result.failure(const NotFoundFailure('User not found.'));
      }

      await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(
          role: Value(role.toValue()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updatedRow = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(userId))).getSingle();
      final updatedUser = UserEntity(
        id: updatedRow.id,
        username: updatedRow.username,
        role: UserRole.fromString(updatedRow.role),
        isEnabled: updatedRow.isEnabled,
        createdAt: updatedRow.createdAt,
        lastLoginAt: updatedRow.lastLoginAt,
      );

      await _auditLogRepo.recordLog(
        userId: actor.id,
        username: actor.username,
        action: 'ROLE_CHANGED',
        details:
            'Changed role of ${updatedUser.username} from ${userRow.role} to ${role.name}.',
      );

      return Result.success(updatedUser);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update user role: $e'));
    }
  }

  @override
  Future<Result<UserEntity>> toggleUserEnabled({
    required int userId,
    required bool isEnabled,
  }) async {
    try {
      final actor = await _getActiveActor();
      if (actor == null || !actor.isAdmin) {
        return Result.failure(
          const UnauthorizedFailure(
            'Only administrators can enable/disable users.',
          ),
        );
      }

      if (actor.id == userId && !isEnabled) {
        return Result.failure(
          const ValidationFailure(
            'Administrators cannot disable their own account.',
          ),
        );
      }

      final userRow = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (userRow == null) {
        return Result.failure(const NotFoundFailure('User not found.'));
      }

      await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(
          isEnabled: Value(isEnabled),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updatedRow = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(userId))).getSingle();
      final updatedUser = UserEntity(
        id: updatedRow.id,
        username: updatedRow.username,
        role: UserRole.fromString(updatedRow.role),
        isEnabled: updatedRow.isEnabled,
        createdAt: updatedRow.createdAt,
        lastLoginAt: updatedRow.lastLoginAt,
      );

      await _auditLogRepo.recordLog(
        userId: actor.id,
        username: actor.username,
        action: isEnabled ? 'USER_ENABLED' : 'USER_DISABLED',
        details:
            '${isEnabled ? "Enabled" : "Disabled"} user ${updatedUser.username}.',
      );

      return Result.success(updatedUser);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to toggle user status: $e'),
      );
    }
  }

  @override
  Future<Result<void>> resetUserPassword({
    required int userId,
    required String newPassword,
  }) async {
    try {
      final actor = await _getActiveActor();
      if (actor == null || !actor.isAdmin) {
        return Result.failure(
          const UnauthorizedFailure(
            'Only administrators can reset user passwords.',
          ),
        );
      }

      final userRow = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (userRow == null) {
        return Result.failure(const NotFoundFailure('User not found.'));
      }

      final hash = PasswordHash.hashPassword(newPassword);
      await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(
          passwordHash: Value(hash),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await _auditLogRepo.recordLog(
        userId: actor.id,
        username: actor.username,
        action: 'PASSWORD_RESET',
        details: 'Reset password for user ${userRow.username}.',
      );

      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to reset user password: $e'),
      );
    }
  }
}
