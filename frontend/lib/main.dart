import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_page.dart';
import 'screens/home/home_page.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'utils/constants.dart';
import 'services/notification_service.dart';
// UI demo files exist but are not used; app runs normally.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
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
          create: (_) =>
              ApiService(baseUrl: Constants.apiBaseUrl)..setToken(initialToken),
        ),
        Provider(create: (_) => SocketService()),
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
