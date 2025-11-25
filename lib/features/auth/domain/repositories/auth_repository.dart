import '../../../../core/utils/result.dart';
import '../entities/user.dart';

/// Authentication repository interface
abstract class AuthRepository {
  Future<Result<Map<String, dynamic>>> login({
    required String email,
    required String password,
  });

  Future<Result<void>> logout();

  Future<Result<User?>> getCurrentUser();

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Result<String?>> getStoredToken();

  Future<Result<void>> storeToken(String token);

  Future<Result<void>> clearToken();
}
