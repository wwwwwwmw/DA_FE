import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';

/// Local data source for authentication (token storage)
abstract class AuthLocalDataSource {
  Future<String?> getToken();
  Future<void> storeToken(String token);
  Future<void> clearToken();
}

/// Implementation of AuthLocalDataSource using SharedPreferences
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  static const String _tokenKey = 'token';

  @override
  Future<String?> getToken() async {
    try {
      return sharedPreferences.getString(_tokenKey);
    } catch (e) {
      throw CacheException(message: 'Lỗi khi đọc token: ${e.toString()}');
    }
  }

  @override
  Future<void> storeToken(String token) async {
    try {
      final result = await sharedPreferences.setString(_tokenKey, token);
      if (!result) {
        throw const CacheException(message: 'Không thể lưu token');
      }
    } catch (e) {
      throw CacheException(message: 'Lỗi khi lưu token: ${e.toString()}');
    }
  }

  @override
  Future<void> clearToken() async {
    try {
      await sharedPreferences.remove(_tokenKey);
    } catch (e) {
      throw CacheException(message: 'Lỗi khi xóa token: ${e.toString()}');
    }
  }
}
