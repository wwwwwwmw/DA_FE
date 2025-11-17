import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../../models/event.dart';
import 'package:intl/intl.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _format = CalendarFormat.month;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final me = api.currentUser;
    final eventsByDay = <DateTime, List<EventModel>>{};
    for (final e in api.events) {
      final day = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      eventsByDay.putIfAbsent(day, () => []).add(e);
    }

    List<EventModel> selectedEvents = [];
    final sel = _selectedDay ?? DateTime.now();
    final selKey = DateTime(sel.year, sel.month, sel.day);
    selectedEvents = eventsByDay[selKey] ?? [];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      selectedEvents = selectedEvents.where((e) => (e.title.toLowerCase()).contains(q)).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextFormField(
            decoration: const InputDecoration(
              hintText: 'Tìm kiếm sự kiện...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        Stack(
          children: [
            TableCalendar<EventModel>(
          firstDay: DateTime.utc(2010, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _format,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (f) => setState(() => _format = f),
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return eventsByDay[key] ?? [];
          },
            ),
            Positioned(
              right: 12,
              top: 6,
              child: PopupMenuButton<CalendarFormat>(
                tooltip: 'Chọn chế độ hiển thị',
                onSelected: (f) => setState(() => _format = f),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: CalendarFormat.week, child: Text('Tuần')),
                  PopupMenuItem(value: CalendarFormat.twoWeeks, child: Text('2 tuần')),
                  PopupMenuItem(value: CalendarFormat.month, child: Text('Tháng')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_format == CalendarFormat.week ? 'Tuần' : _format == CalendarFormat.twoWeeks ? '2 tuần' : 'Tháng'),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down),
                  ]),
                ),
              ),
            )
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => api.fetchEvents(),
            child: ListView.builder(
              itemCount: selectedEvents.length,
              itemBuilder: (ctx, i) {
                final e = selectedEvents[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(e.title),
                    subtitle: Text('${DateFormat('HH:mm').format(e.startTime)} - ${DateFormat('HH:mm').format(e.endTime)} • ${e.status}'),
                    trailing: (me != null && e.participants.isNotEmpty)
                        ? Builder(builder: (_) {
                            final mine = e.participants.firstWhere(
                              (p) => p.userId == me.id,
                              orElse: () => e.participants.first,
                            );
                            if (mine.userId != me.id) return const SizedBox.shrink();
                            final pid = mine.id;
                            return Wrap(spacing: 8, children: [
                              TextButton(onPressed: ()=>api.rsvp(pid,'accepted'), child: const Text('Tham gia')),
                              TextButton(onPressed: ()=>api.rsvp(pid,'declined'), child: const Text('Từ chối')),
                              TextButton(
                                onPressed: () async {
                                  final controller = TextEditingController();
                                  final reason = await showDialog<String>(context: context, builder: (ctx) {
                                    return AlertDialog(
                                      title: const Text('Yêu cầu điều chỉnh'),
                                      content: TextField(
                                        controller: controller,
                                        maxLines: 4,
                                        decoration: const InputDecoration(
                                          hintText: 'Nhập lý do/ghi chú...',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: ()=>Navigator.of(ctx).pop(), child: const Text('Hủy')),
                                        ElevatedButton(onPressed: (){ Navigator.of(ctx).pop(controller.text.trim()); }, child: const Text('Gửi')),
                                      ],
                                    );
                                  });
                                  if (reason != null && reason.isNotEmpty) {
                                    await api.requestParticipantAdjustment(pid, reason);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu điều chỉnh')));
                                    }
                                  }
                                },
                                child: const Text('Yêu cầu điều chỉnh'),
                              ),
                            ]);
                          })
                        : null,
                  ),
                );
              },
            ),
          ),
        )
      ],
    );
  }
}
