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
    setState(()=>_loading=true);
    try {
      final ev = await context.read<ApiService>().fetchEventById(widget.eventId);
      setState((){ _event = ev; _error = null; });
    } catch (e) {
      setState((){ _error = '$e'; });
    } finally {
      if (mounted) setState(()=>_loading=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    final e = _event!;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết lịch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${DateFormat('dd/MM/yyyy HH:mm').format(e.startTime)} - ${DateFormat('dd/MM/yyyy HH:mm').format(e.endTime)}'),
          const SizedBox(height: 8),
          Text('Trạng thái: ${e.status}'),
          if (e.description != null) ...[
            const SizedBox(height: 16),
            Text(e.description!),
          ]
        ]),
      ),
    );
  }
}
