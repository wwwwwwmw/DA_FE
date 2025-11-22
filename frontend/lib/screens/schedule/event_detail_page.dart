import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/event.dart';
import 'package:intl/intl.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  EventModel? _event;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ev = await context.read<ApiService>().fetchEventById(
        widget.eventId,
      );
      setState(() {
        _event = ev;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null)
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    final e = _event!;
    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(e.type == 'meeting' ? 'Meeting' : 'Work')),
                Chip(label: Text('Status: ${e.status}')),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PropRow(
                      icon: Icons.access_time,
                      label: 'Start',
                      value: DateFormat('dd/MM HH:mm').format(e.startTime),
                    ),
                    const Divider(height: 24),
                    _PropRow(
                      icon: Icons.timelapse,
                      label: 'End',
                      value: DateFormat('dd/MM HH:mm').format(e.endTime),
                    ),
                    const Divider(height: 24),
                    _PropRow(
                      icon: Icons.group_outlined,
                      label: 'Participants',
                      value: e.participants.length.toString(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              e.description?.trim().isNotEmpty == true
                  ? e.description!.trim()
                  : '—',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _load(),
                    child: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: e.status == 'completed'
                        ? null
                        : () async {
                            final api = context.read<ApiService>();
                            try {
                              await api.updateEvent(e.id, status: 'completed');
                              await _load();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sự kiện đã đánh dấu hoàn thành',
                                  ),
                                ),
                              );
                            } catch (err) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cập nhật thất bại'),
                                ),
                              );
                            }
                          },
                    child: Text(
                      e.status == 'completed' ? 'Completed' : 'Mark as Done',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PropRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PropRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
