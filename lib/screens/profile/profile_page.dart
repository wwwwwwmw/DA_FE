import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../tasks/task_status_page.dart';
import 'edit_profile_page.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    api.fetchTaskStats();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final u = api.currentUser;
    final stats = api.taskStats;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Column(children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: cs.primaryContainer,
              backgroundImage: _avatarImageProvider(u?.avatarUrl),
              child: u?.avatarUrl == null ? Icon(Icons.person, size: 50, color: cs.primary) : null,
            ),
            const SizedBox(height: 12),
            Text(u?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(u?.email ?? '', style: const TextStyle(color: Colors.grey)),
          ]),
        ),
        const SizedBox(height: 24),
        _StatCard(
          title: 'Hoàn thành',
          value: stats['completed'] ?? 0,
          color: cs.tertiary,
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Đang thực hiện',
          value: stats['in_progress'] ?? 0,
          color: cs.primary,
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Cần làm',
          value: stats['todo'] ?? 0,
          color: cs.secondary,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          icon: const Icon(Icons.edit),
          label: const Text('Chỉnh sửa Hồ sơ'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskStatusPage())),
          icon: const Icon(Icons.pie_chart),
          label: const Text('Trạng thái Nhiệm vụ'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          style: TextButton.styleFrom(backgroundColor: cs.errorContainer, foregroundColor: cs.onErrorContainer),
          onPressed: () {
            api.logout();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ]),
    );
  }

  ImageProvider? _avatarImageProvider(String? dataUrl) {
    if (dataUrl == null) return null;
    if (dataUrl.startsWith('data:')) {
      try {
        final base64Part = dataUrl.split(',').last;
        return MemoryImage(const Base64Decoder().convert(base64Part));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(dataUrl);
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))],
      ),
      child: Row(children: [
  Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.task_alt, color: color)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('$value nhiệm vụ', style: const TextStyle(color: Colors.grey)),
        ])),
        Text(value.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
