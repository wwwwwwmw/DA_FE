import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_page.dart';
import 'screens/home/home_page.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'utils/constants.dart';
import 'services/notification_service.dart';

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
        ChangeNotifierProvider(create: (_) => ApiService(baseUrl: Constants.apiBaseUrl)..setToken(initialToken)),
        Provider(create: (_) => SocketService()),
      ],
      child: MaterialApp(
        title: 'company_schedule',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8.0),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            labelStyle: const TextStyle(color: Colors.black54),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              // Use finite min width; explicit full-width buttons will wrap in SizedBox(width: double.infinity)
              minimumSize: const Size(80, 50),
            ),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            centerTitle: true,
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            selectedItemColor: Colors.indigo,
            unselectedItemColor: Colors.grey.shade600,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
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
                    await NotificationService.instance.showNow(title: title, body: message);
                  } catch (_) {
                    await NotificationService.instance.showNow(title: 'Thông báo mới', body: data.toString());
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
