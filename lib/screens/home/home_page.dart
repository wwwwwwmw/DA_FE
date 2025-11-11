import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../schedule/schedule_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final _pages = const [SchedulePage(), NotificationsPage(), ProfilePage()];

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    api.fetchEvents();
    api.fetchNotifications();
    final socket = context.read<SocketService>();
    socket.connect(
      baseUrl: Constants.apiBaseUrl,
      token: api.token,
      onNotification: (_) => api.fetchNotifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch Công Tác')),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Thông báo'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
