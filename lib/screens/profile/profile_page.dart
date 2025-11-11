import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final u = api.currentUser;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tài khoản', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (u != null) ...[
          Text('Họ tên: ${u.name}'),
          Text('Email: ${u.email}'),
          Text('Quyền: ${u.role}'),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => api.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        )
      ]),
    );
  }
}
