import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

/// Remote data source for authentication
abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<UserModel?> getCurrentUser();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

/// Implementation of AuthRemoteDataSource using Dio
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        final data = response.data as Map<String, dynamic>?;
        final message = data?['message'] as String? ?? 'Đăng nhập thất bại';
        throw AuthException(message: message, statusCode: response.statusCode);
      }

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Lỗi server không xác định',
          statusCode: response.statusCode,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException(message: 'Không thể kết nối đến server');
      }

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data as Map<String, dynamic>?;
        final message = data?['message'] as String? ?? 'Lỗi không xác định';

        if (statusCode == 401 || statusCode == 403) {
          throw AuthException(message: message, statusCode: statusCode);
        }

        throw ServerException(message: message, statusCode: statusCode);
      }

      throw NetworkException(message: e.message ?? 'Lỗi mạng');
    } catch (e) {
      throw ServerException(message: 'Lỗi không xác định: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dio.post('/api/auth/logout');
    } on DioException catch (e) {
      // Logout can fail silently in most cases
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException(message: 'Không thể kết nối đến server');
      }

      if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
        throw ServerException(
          message: 'Lỗi server khi đăng xuất',
          statusCode: e.response!.statusCode,
        );
      }
      // Other errors during logout are usually not critical
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await dio.get('/api/auth/me');

      if (response.statusCode == 401) {
        throw const AuthException(message: 'Phiên đăng nhập đã hết hạn');
      }

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Lỗi khi lấy thông tin user',
          statusCode: response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException(message: 'Không thể kết nối đến server');
      }

      if (e.response != null) {
        final statusCode = e.response!.statusCode;

        if (statusCode == 401) {
          throw const AuthException(message: 'Phiên đăng nhập đã hết hạn');
        }

        throw ServerException(
          message: 'Lỗi server khi lấy thông tin user',
          statusCode: statusCode,
        );
      }

      throw NetworkException(message: e.message ?? 'Lỗi mạng');
    } catch (e) {
      throw ServerException(message: 'Lỗi không xác định: ${e.toString()}');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await dio.put(
        '/api/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

      if (response.statusCode == 400) {
        final data = response.data as Map<String, dynamic>?;
        final message = data?['message'] as String? ?? 'Dữ liệu không hợp lệ';
        throw ValidationException(message: message);
      }

      if (response.statusCode == 401) {
        throw const AuthException(message: 'Mật khẩu hiện tại không đúng');
      }

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Lỗi khi đổi mật khẩu',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException(message: 'Không thể kết nối đến server');
      }

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final data = e.response!.data as Map<String, dynamic>?;
        final message = data?['message'] as String? ?? 'Lỗi không xác định';

        if (statusCode == 400) {
          throw ValidationException(message: message);
        }

        if (statusCode == 401) {
          throw const AuthException(message: 'Mật khẩu hiện tại không đúng');
        }

        throw ServerException(message: message, statusCode: statusCode);
      }

      throw NetworkException(message: e.message ?? 'Lỗi mạng');
    } catch (e) {
      throw ServerException(message: 'Lỗi không xác định: ${e.toString()}');
    }
  }
}
