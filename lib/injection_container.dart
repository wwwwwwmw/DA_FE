import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/constants.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/auth_usecases.dart';

/// Simple Service Locator for dependency injection
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  static ServiceLocator get instance => _instance;

  final Map<Type, Object> _services = {};

  /// Register a service
  void registerSingleton<T extends Object>(T service) {
    _services[T] = service;
  }

  /// Register a lazy singleton (factory function)
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _services[T] = factory;
  }

  /// Get a service
  T get<T extends Object>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T is not registered');
    }

    if (service is T Function()) {
      final instance = service();
      _services[T] = instance; // Cache the instance
      return instance;
    }

    return service as T;
  }

  /// Check if service is registered
  bool isRegistered<T extends Object>() {
    return _services.containsKey(T);
  }

  /// Clear all services (for testing)
  void reset() {
    _services.clear();
  }
}

/// Initialize dependency injection
Future<void> initializeDependencies() async {
  final sl = ServiceLocator.instance;

  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);

  final dio = Dio(
    BaseOptions(
      baseUrl: Constants.apiBaseUrl,
      headers: {'ngrok-skip-browser-warning': 'true'},
      validateStatus: (code) => code != null && code < 500,
    ),
  );
  sl.registerSingleton<Dio>(dio);

  // Data sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl.get()),
  );

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl.get()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl.get(),
      localDataSource: sl.get(),
    ),
  );

  // Use cases
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(sl.get()));

  sl.registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(sl.get()));

  sl.registerLazySingleton<GetCurrentUserUseCase>(
    () => GetCurrentUserUseCase(sl.get()),
  );

  sl.registerLazySingleton<ChangePasswordUseCase>(
    () => ChangePasswordUseCase(sl.get()),
  );

  sl.registerLazySingleton<GetStoredTokenUseCase>(
    () => GetStoredTokenUseCase(sl.get()),
  );
}
