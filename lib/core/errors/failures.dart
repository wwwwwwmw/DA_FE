/// Base failure class for handling errors in the domain layer
abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode;

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;
}

/// Failure for server-related errors
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

/// Failure for network-related errors
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.statusCode});
}

/// Failure for cache-related errors
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.statusCode});
}

/// Failure for validation errors
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.statusCode});
}

/// Failure for authentication errors
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode});
}

/// Failure for authorization errors
class AuthorizationFailure extends Failure {
  const AuthorizationFailure({required super.message, super.statusCode});
}
