import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final list = api.notifications;
    return RefreshIndicator(
      onRefresh: () async => api.fetchNotifications(),
      child: ListView.separated(
        itemBuilder: (_, i) {
          final n = list[i];
          return ListTile(
            leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications_active),
            title: Text(n.title),
            subtitle: Text(n.message),
            trailing: Text('${n.createdAt.hour.toString().padLeft(2,'0')}:${n.createdAt.minute.toString().padLeft(2,'0')}'),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: list.length,
      ),
    );
  }
}
