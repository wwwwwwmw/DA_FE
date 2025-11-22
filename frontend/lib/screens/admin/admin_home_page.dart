import 'package:flutter/material.dart';
import 'users_tab.dart';
import 'departments_tab.dart';
import 'rooms_tab.dart';
import 'events_admin_tab.dart';
import 'system_tab.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Bảng điều khiển quản trị',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Người dùng'),
            Tab(text: 'Phòng ban'),
            Tab(text: 'Phòng họp'),
            Tab(text: 'Lịch'),
            Tab(text: 'Hệ thống'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              AdminUsersTab(),
              DepartmentsTab(),
              RoomsTab(),
              EventsAdminTab(),
              SystemTab(),
            ],
          ),
        ),
      ],
    );
  }
}
