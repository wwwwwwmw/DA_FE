/// A generic result type for handling success and failure states
sealed class Result<T> {
  const Result();
}

/// Success result with data
final class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// Failure result with error
final class Error<T> extends Result<T> {
  final Exception exception;

  const Error(this.exception);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Error<T> &&
          runtimeType == other.runtimeType &&
          exception == other.exception;

  @override
  int get hashCode => exception.hashCode;

  @override
  String toString() => 'Error($exception)';
}

/// Extension methods for Result
extension ResultExtension<T> on Result<T> {
  /// Check if the result is successful
  bool get isSuccess => this is Success<T>;

  /// Check if the result is an error
  bool get isError => this is Error<T>;

  /// Get the data if successful, null otherwise
  T? get dataOrNull => switch (this) {
    Success<T>(data: final data) => data,
    Error<T>() => null,
  };

  /// Get the exception if error, null otherwise
  Exception? get exceptionOrNull => switch (this) {
    Success<T>() => null,
    Error<T>(exception: final exception) => exception,
  };

  /// Map the success data to another type
  Result<R> map<R>(R Function(T data) mapper) => switch (this) {
    Success<T>(data: final data) => Success(mapper(data)),
    Error<T>(exception: final exception) => Error<R>(exception),
  };

  /// Map the error to another exception
  Result<T> mapError(Exception Function(Exception exception) mapper) =>
      switch (this) {
        Success<T>(data: final data) => Success(data),
        Error<T>(exception: final exception) => Error(mapper(exception)),
      };

  /// Perform an action when the result is successful
  Result<T> onSuccess(void Function(T data) action) {
    if (this case Success<T>(data: final data)) {
      action(data);
    }
    return this;
  }

  /// Perform an action when the result is an error
  Result<T> onError(void Function(Exception exception) action) {
    if (this case Error<T>(exception: final exception)) {
      action(exception);
    }
    return this;
  }

  /// Get the data or throw the exception
  T getOrThrow() => switch (this) {
    Success<T>(data: final data) => data,
    Error<T>(exception: final exception) => throw exception,
  };

  /// Get the data or return a default value
  T getOrElse(T defaultValue) => switch (this) {
    Success<T>(data: final data) => data,
    Error<T>() => defaultValue,
  };
}
