import '../../../../core/utils/result.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';

/// Implementation of AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Result<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await remoteDataSource.login(
        email: email,
        password: password,
      );

      // Store token if login successful
      final token = result['token'] as String?;
      if (token != null) {
        await localDataSource.storeToken(token);
      }

      return Success(result);
    } on AuthException catch (e) {
      return Error(e);
    } on NetworkException catch (e) {
      return Error(e);
    } on ServerException catch (e) {
      return Error(e);
    } on CacheException catch (e) {
      return Error(e);
    } catch (e) {
      return Error(Exception('Lỗi không xác định: ${e.toString()}'));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      // Clear local token first
      await localDataSource.clearToken();

      // Then call remote logout (can fail silently)
      try {
        await remoteDataSource.logout();
      } catch (e) {
        // Remote logout failure is not critical
        // Token is already cleared locally
      }

      return const Success(null);
    } on CacheException catch (e) {
      return Error(e);
    } catch (e) {
      return Error(Exception('Lỗi khi đăng xuất: ${e.toString()}'));
    }
  }

  @override
  Future<Result<User?>> getCurrentUser() async {
    try {
      // Check if we have a token first
      final token = await localDataSource.getToken();
      if (token == null) {
        return const Success(null);
      }

      final userModel = await remoteDataSource.getCurrentUser();
      if (userModel == null) {
        return const Success(null);
      }

      return Success(userModel.toEntity());
    } on AuthException catch (e) {
      // Token might be expired, clear it
      try {
        await localDataSource.clearToken();
      } catch (_) {}
      return Error(e);
    } on NetworkException catch (e) {
      return Error(e);
    } on ServerException catch (e) {
      return Error(e);
    } on CacheException catch (e) {
      return Error(e);
    } catch (e) {
      return Error(Exception('Lỗi khi lấy thông tin user: ${e.toString()}'));
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      return const Success(null);
    } on ValidationException catch (e) {
      return Error(e);
    } on AuthException catch (e) {
      return Error(e);
    } on NetworkException catch (e) {
      return Error(e);
    } on ServerException catch (e) {
      return Error(e);
    } catch (e) {
      return Error(Exception('Lỗi khi đổi mật khẩu: ${e.toString()}'));
    }
  }

  @override
  Future<Result<String?>> getStoredToken() async {
    try {
      final token = await localDataSource.getToken();
      return Success(token);
    } on CacheException catch (e) {
      return Error(e);
    } catch (e) {
      return Error(Exception('Lỗi khi đọc token: ${e.toString()}'));
    }
  }

  @override
  Future<Result<void>> storeToken(String token) async {
    try {
      await localDataSource.storeToken(token);
      return const Success(null);
    } on CacheException catch (e) {
      return Error(e);
    } catch (e) {
      return Error(Exception('Lỗi khi lưu token: ${e.toString()}'));
    }
  }

  @override
  Future<Result<void>> clearToken() async {
    try {
      await localDataSource.clearToken();
      return const Success(null);
    } on CacheException catch (e) {
      return Error(e);
    } catch (e) {
      return Error(Exception('Lỗi khi xóa token: ${e.toString()}'));
    }
  }
}
