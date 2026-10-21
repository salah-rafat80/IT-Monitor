import '../../../../core/utils/result.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<bool>> hasAdminAccount();
  Future<Result<UserEntity>> createInitialAdmin({
    required String username,
    required String password,
  });
  Future<Result<UserEntity>> login({
    required String username,
    required String password,
  });
  Future<Result<UserEntity?>> getCurrentUser();
  Future<Result<void>> logout();
}
