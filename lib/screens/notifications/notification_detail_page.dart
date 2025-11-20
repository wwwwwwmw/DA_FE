import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/notification.dart';
import '../tasks/task_detail_page.dart';
import '../schedule/event_detail_page.dart';

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
          const SizedBox(height: 16),
          if (n.refType == 'task' || n.refType == 'event') ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (n.refType == 'task')
                OutlinedButton.icon(
                  icon: const Icon(Icons.task_alt, size: 18),
                  label: const Text('Xem công việc'),
                  onPressed: () async {
                    try {
                      final task = await context.read<ApiService>().fetchTaskById(n.refId!);
                      if (!mounted) return;
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được công việc: $e')));
                    }
                  },
                ),
              if (n.refType == 'event')
                OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 18),
                  label: const Text('Xem lịch'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailPage(eventId: n.refId!)));
                  },
                ),
              if (n.refType == 'event') ...[
                Builder(builder: (ctx) {
                  final api = ctx.watch<ApiService>();
                  final canApprove = api.currentUser?.role == 'admin';
                  // Hide approve/deny if not admin or event already processed (status != pending)
                  if (!canApprove) return const SizedBox.shrink();
                  final ev = api.events.where((e) => e.id == n.refId).isNotEmpty
                      ? api.events.firstWhere((e) => e.id == n.refId)
                      : null;
                  if (ev != null && ev.status != 'pending') return const SizedBox.shrink();
                  return Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        label: const Text('Duyệt lịch'),
                        onPressed: () async {
                          try {
                            await api.updateEvent(n.refId!, status: 'approved');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã duyệt lịch')));
                            await api.fetchEvents();
                            await api.fetchNotifications();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        label: const Text('Không duyệt'),
                        onPressed: () async {
                          try {
                            await api.updateEvent(n.refId!, status: 'rejected');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã từ chối lịch')));
                            await api.fetchEvents();
                            await api.fetchNotifications();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                      ),
                    ),
                  ]);
                })
              ],
              if (n.refType == 'task') ...[
                Builder(builder: (ctx) {
                  final api = ctx.watch<ApiService>();
                  final isManager = api.currentUser?.role == 'manager' || api.currentUser?.role == 'admin';
                  final isRejection = n.title.contains('Từ chối');
                  if (!isManager || !isRejection) return const SizedBox.shrink();
                  return Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        label: const Text('Duyệt'),
                        onPressed: () async {
                          try {
                            await api.approveTaskRejection(n.refId!);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chấp thuận yêu cầu thay đổi')));
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        label: const Text('Không duyệt'),
                        onPressed: () async {
                          try {
                            await api.denyTaskRejection(n.refId!);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi thông báo không duyệt')));
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        },
                      ),
                    ),
                  ]);
                }),
              ]
            ]),
          ],
        ]),
      ),
    );
  }
}
