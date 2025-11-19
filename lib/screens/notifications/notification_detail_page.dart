import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/notification.dart';

class NotificationDetailPage extends StatefulWidget {
  final NotificationModel notification;
  const NotificationDetailPage({super.key, required this.notification});

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _markAsReadIfNeeded();
  }

  Future<void> _markAsReadIfNeeded() async {
    if (!widget.notification.isRead && !_marking) {
      setState(() => _marking = true);
      try { await context.read<ApiService>().markNotificationRead(widget.notification.id); } finally { if(mounted) setState(() => _marking = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết thông báo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${n.createdAt}'),
          const Divider(height: 24),
          Text(n.message, style: const TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }
}
