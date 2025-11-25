import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'notification_detail_page.dart';
// Removed task/event detail buttons from list; navigation now in detail page.
import '../../widgets/notification_list_item.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final list = [...api.notifications];
    // Sort newest first (assuming server order may vary)
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async => api.fetchNotifications(),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final n = list[i];
            return NotificationListItem(
              n: n,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationDetailPage(notification: n),
                  ),
                );
                if (!context.mounted) return;
                await api.fetchNotifications();
              },
            );
          },
        ),
      ),
    );
  }
}
