import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/constants.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../schedule/schedule_page.dart';
import '../tasks/home_tasks_page.dart';
import '../admin/admin_home_page.dart';
import '../manager/manager_home_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    api.loadMe();
    api.fetchEvents();
    api.fetchNotifications();
    final socket = context.read<SocketService>();
    socket.connect(
      baseUrl: Constants.apiBaseUrl,
      token: api.token,
      onNotification: (_) => api.fetchNotifications(),
      onDataUpdated: (_) {
        // Generic refresh when server announces data changes
        api.fetchNotifications();
        api.fetchEvents();
        api.fetchProjects();
        api.fetchTasks();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final role = api.currentUser?.role;
    final isAdmin = role == 'admin';
    final isManager = role == 'manager';
    final pages = [
      const HomeTasksPage(), // new tasks home
      const SchedulePage(),
      const NotificationsPage(),
      const ProfilePage(),
      if (isAdmin) const AdminHomePage(),
      if (!isAdmin && isManager) const ManagerHomePage(),
    ];
    final unread = api.notifications.where((n) => !n.isRead).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch Công Tác')),
      body: pages[_index.clamp(0, pages.length - 1)],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _index.clamp(0, pages.length - 1),
        onTap: (i) => setState(() => _index = i),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
                if (unread > 0)
                  Positioned(
                    right: -6,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: BorderRadius.circular(10)),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
            label: 'Thông báo',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
          if (isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Quản trị'),
          if (!isAdmin && isManager) const BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Quản lý'),
        ],
      ),
    );
  }
}
