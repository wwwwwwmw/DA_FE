import '../../../../core/utils/result.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for user login
class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Result<Map<String, dynamic>>> call({
    required String email,
    required String password,
  }) async {
    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      return Error(Exception('Email and password are required'));
    }

    if (!_isValidEmail(email)) {
      return Error(Exception('Invalid email format'));
    }

    return await repository.login(email: email, password: password);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

/// Use case for user logout
class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<Result<void>> call() async {
    return await repository.logout();
  }
}

/// Use case for getting current user
class GetCurrentUserUseCase {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  Future<Result<User?>> call() async {
    return await repository.getCurrentUser();
  }
}

/// Use case for changing password
class ChangePasswordUseCase {
  final AuthRepository repository;

  ChangePasswordUseCase(this.repository);

  Future<Result<void>> call({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Basic validation
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      return Error(Exception('Current password and new password are required'));
    }

    if (newPassword.length < 6) {
      return Error(Exception('New password must be at least 6 characters'));
    }

    if (currentPassword == newPassword) {
      return Error(
        Exception('New password must be different from current password'),
      );
    }

    return await repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}

/// Use case for checking authentication status
class GetStoredTokenUseCase {
  final AuthRepository repository;

  GetStoredTokenUseCase(this.repository);

  Future<Result<String?>> call() async {
    return await repository.getStoredToken();
  }
}
