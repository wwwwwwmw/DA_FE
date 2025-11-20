import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'notification_detail_page.dart';
import '../tasks/task_detail_page.dart';
import '../schedule/event_detail_page.dart';
import '../../widgets/notification_list_item.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final list = api.notifications;
    return RefreshIndicator(
      onRefresh: () async => api.fetchNotifications(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final n = list[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NotificationListItem(
                n: n,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationDetailPage(notification: n)));
                  if (!context.mounted) return;
                  await api.fetchNotifications();
                },
              ),
              if (n.refType == 'task' || n.refType == 'event')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(spacing: 8, children: [
                    if (n.refType == 'task')
                      OutlinedButton.icon(icon: const Icon(Icons.task_alt, size: 18), label: const Text('Xem công việc'), onPressed: () async {
                        try {
                          final task = await api.fetchTaskById(n.refId!);
                          if (!context.mounted) return;
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được công việc: $e')));
                        }
                      }),
                    if (n.refType == 'task' && (api.currentUser?.role == 'manager' || api.currentUser?.role == 'admin') && n.title.contains('Từ chối'))
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        label: const Text('Duyệt'),
                        onPressed: () async {
                          try { await api.approveTaskRejection(n.refId!); if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chấp thuận từ chối nhiệm vụ')));} catch (e) { if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));} },
                      ),
                    if (n.refType == 'task' && (api.currentUser?.role == 'manager' || api.currentUser?.role == 'admin') && n.title.contains('Từ chối'))
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        label: const Text('Không duyệt'),
                        onPressed: () async {
                          try { await api.denyTaskRejection(n.refId!); if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi thông báo không duyệt')));} catch (e) { if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));} },
                      ),
                    if (n.refType == 'event')
                      OutlinedButton.icon(icon: const Icon(Icons.event, size: 18), label: const Text('Xem lịch công tác'), onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailPage(eventId: n.refId!)));
                        if (!context.mounted) return;
                      }),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}
