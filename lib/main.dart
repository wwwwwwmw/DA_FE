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
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
        home: initialToken == null ? const LoginPage() : const HomePage(),
      ),
    );
  }
}
