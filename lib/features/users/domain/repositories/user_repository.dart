import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class UserRepository {
  Future<Result<List<UserEntity>>> getUsers();
  Future<Result<UserEntity>> createUser({
    required String username,
    required String password,
    required UserRole role,
  });
  Future<Result<UserEntity>> updateUserRole({
    required int userId,
    required UserRole role,
  });
  Future<Result<UserEntity>> toggleUserEnabled({
    required int userId,
    required bool isEnabled,
  });
  Future<Result<void>> resetUserPassword({
    required int userId,
    required String newPassword,
  });
}
