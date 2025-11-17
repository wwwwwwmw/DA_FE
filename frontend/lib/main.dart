import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_page.dart';
import 'screens/home/home_page.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        title: 'Lịch Công Tác',
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
      ),
    );
  }
}
