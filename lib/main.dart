import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'injection_container.dart';
import 'screens/auth/login_page.dart';
import 'screens/home/home_page.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'core/constants/constants.dart';
import 'services/notification_service.dart';
import 'features/auth/domain/usecases/auth_usecases.dart';
import 'core/utils/result.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependencies
  await initializeDependencies();

  // Initialize notification service
  await NotificationService.instance.init();

  // Check for stored token using clean architecture
  final getStoredTokenUseCase = ServiceLocator.instance
      .get<GetStoredTokenUseCase>();
  final tokenResult = await getStoredTokenUseCase();

  String? token;
  if (tokenResult is Success<String?>) {
    token = tokenResult.data;
  } else if (tokenResult is Error<String?>) {
    token = null;
  }

  runApp(MyApp(initialToken: token));
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  const MyApp({super.key, this.initialToken});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final apiService = ApiService(baseUrl: Constants.apiBaseUrl);
            if (initialToken != null) {
              apiService.setToken(initialToken);
            }
            return apiService;
          },
        ),
        Provider(create: (_) => SocketService()),
        // Add Clean Architecture dependencies to provider tree
        Provider<ServiceLocator>(create: (_) => ServiceLocator.instance),
      ],
      child: MaterialApp(
        title: 'company_schedule',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2EE6A6),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            color: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF17C58A), width: 2),
            ),
            labelStyle: const TextStyle(color: Colors.black54),
            hintStyle: const TextStyle(color: Colors.black38),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2EE6A6),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              minimumSize: const Size(80, 50),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            centerTitle: true,
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            selectedItemColor: const Color(0xFF2EE6A6),
            unselectedItemColor: Colors.grey.shade600,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
          ),
          chipTheme: ChipThemeData(
            selectedColor: const Color(0xFFE6FBF4),
            backgroundColor: const Color(0xFFF3F6F9),
            shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        home: initialToken == null ? const LoginPage() : const HomePage(),
        builder: (context, child) {
          // After providers exist, perform one-time socket + initial fetch wiring
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final api = context.read<ApiService>();
            final socket = context.read<SocketService>();
            if (api.token != null) {
              socket.connect(
                baseUrl: Constants.socketBaseUrl,
                token: api.token,
                onNotification: (data) async {
                  try {
                    final title = data['title']?.toString() ?? 'Thông báo mới';
                    final message = data['message']?.toString() ?? '';
                    await NotificationService.instance.showNow(
                      title: title,
                      body: message,
                    );
                  } catch (_) {
                    await NotificationService.instance.showNow(
                      title: 'Thông báo mới',
                      body: data.toString(),
                    );
                  }
                  await api.fetchNotifications();
                },
                onDataUpdated: (_) async {
                  await api.fetchTasks();
                },
              );
              // Initial data fetch to populate and schedule reminders if not already
              await api.fetchNotifications();
              await api.fetchTasks();
            }
          });
          return child!;
        },
      ),
    );
  }
}
