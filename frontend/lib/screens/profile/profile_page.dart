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
    // Derive task status counts from assignment progress (ignore stored status)
    int todo = 0, inProgress = 0, completed = 0;
    for (final t in api.tasks) {
      final asg = t.assignments;
      final derived = (asg.isNotEmpty && asg.every((a) => a.progress >= 100))
          ? 'completed'
          : (asg.any((a) => a.progress > 0 && a.progress < 100)
                ? 'in_progress'
                : 'todo');
      if (derived == 'completed')
        completed++;
      else if (derived == 'in_progress')
        inProgress++;
      else
        todo++;
    }
    final stats = {
      'completed': completed,
      'in_progress': inProgress,
      'todo': todo,
    };
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: _avatarImageProvider(u?.avatarUrl),
                    child: u?.avatarUrl == null
                        ? Icon(Icons.person, size: 40, color: cs.primary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u?.name ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          u?.email ?? '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Chỉnh sửa',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Task Overview',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _StatRow(stats: stats, cs: cs),
          const SizedBox(height: 24),
          const Text('Actions', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('Trạng thái Nhiệm vụ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TaskStatusPage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Đăng xuất'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    api.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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

class _StatRow extends StatelessWidget {
  final Map<String, int> stats;
  final ColorScheme cs;
  const _StatRow({required this.stats, required this.cs});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _miniStat('Hoàn thành', stats['completed']!, cs.tertiary),
        const SizedBox(width: 8),
        _miniStat('Đang làm', stats['in_progress']!, cs.primary),
        const SizedBox(width: 8),
        _miniStat('Cần làm', stats['todo']!, cs.secondary),
      ],
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
