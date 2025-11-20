import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../../models/event.dart';
import '../../models/task.dart';
import '../../models/user.dart';
// Removed direct DateFormat usage; EventListItemCard handles time formatting
import '../../widgets/event_list_item_card.dart';
import 'event_detail_page.dart';
import '../tasks/task_detail_page.dart';

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
  // Removed separate loaded flag; rely on provider updates.

  @override
  void initState() {
    super.initState();
    // Ensure tasks are loaded for calendar markers
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = context.read<ApiService>();
      try { await api.fetchTasks(); } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final me = api.currentUser;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = bottomInset > 0;
    final eventsByDay = <DateTime, List<EventModel>>{};
    // Map events across their full date span (start -> end inclusive)
    for (final e in api.events) {
      DateTime d = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final end = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
      while (!d.isAfter(end)) {
        eventsByDay.putIfAbsent(d, () => []).add(e);
        d = d.add(const Duration(days: 1));
      }
    }
    // Map tasks across their full date span (start -> end inclusive; if end null, only start day)
    final tasksByDay = <DateTime, List<TaskModel>>{};
    for (final t in api.tasks) {
      if (t.startTime == null) continue;
      DateTime d = DateTime(t.startTime!.year, t.startTime!.month, t.startTime!.day);
      final DateTime end = t.endTime != null
          ? DateTime(t.endTime!.year, t.endTime!.month, t.endTime!.day)
          : d;
      while (!d.isAfter(end)) {
        tasksByDay.putIfAbsent(d, () => []).add(t);
        d = d.add(const Duration(days: 1));
      }
    }

    // Always use selected day (or today) for the lists, regardless of format
    List<EventModel> selectedEvents = [];
    List<TaskModel> selectedTasks = [];
    final sel = _selectedDay ?? DateTime.now();
    final selKey = DateTime(sel.year, sel.month, sel.day);
    selectedEvents = List<EventModel>.from(eventsByDay[selKey] ?? const []);
    selectedTasks = List<TaskModel>.from(tasksByDay[selKey] ?? const []);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      selectedEvents = selectedEvents.where((e) => (e.title.toLowerCase()).contains(q)).toList();
      selectedTasks = selectedTasks.where((t) => (t.title.toLowerCase()).contains(q)).toList();
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, keyboardOpen ? 4 : 8, 12, keyboardOpen ? 0 : 4),
          child: TextFormField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm sự kiện...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: keyboardOpen ? 6 : 10),
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
              // Row height per format; slightly shrink when keyboard is open to avoid overflow
              rowHeight: _format == CalendarFormat.month
                  ? (keyboardOpen ? 34 : 44)
                  : (_format == CalendarFormat.twoWeeks
                      ? (keyboardOpen ? 30 : 38)
                      : (keyboardOpen ? 30 : 38)),
              daysOfWeekHeight: keyboardOpen ? 12 : 18,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (f) => setState(() => _format = f),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                headerPadding: EdgeInsets.symmetric(vertical: keyboardOpen ? 2 : 6),
              ),
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return eventsByDay[key] ?? [];
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (ctx, date, events) {
                  final key = DateTime(date.year, date.month, date.day);
                  final hasTask = tasksByDay.containsKey(key) && tasksByDay[key]!.isNotEmpty;
                  final hasMeeting = events.any((e) => e.type == 'meeting');
                  final hasWork = events.any((e) => e.type == 'work');
                  if (!hasTask && !hasMeeting && !hasWork) return null;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasTask) _dot(Colors.blue),
                      if (hasMeeting) _dot(Colors.purple),
                      if (hasWork) _dot(Colors.orange),
                    ],
                  );
                },
              ),
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
        if (!keyboardOpen) _legend(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async { await api.fetchEvents(); await api.fetchTasks(); },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Section 1: Tasks
                _sectionHeader('Nhiệm vụ'),
                if (selectedTasks.isEmpty) _emptyText('Không có nhiệm vụ')
                else ...selectedTasks.map((t) => _taskTile(t, me)).toList(),
                const Divider(),
                // Section 2: Lịch họp
                _sectionHeader('Lịch họp'),
                ..._buildEventList(selectedEvents.where((e)=>e.type=='meeting').toList(), me, api),
                if (selectedEvents.where((e)=>e.type=='meeting').isEmpty) _emptyText('Không có lịch họp'),
                const Divider(),
                // Section 3: Lịch công tác (work events)
                _sectionHeader('Lịch công tác'),
                ..._buildEventList(selectedEvents.where((e)=>e.type=='work').toList(), me, api),
                if (selectedEvents.where((e)=>e.type=='work').isEmpty) _emptyText('Không có lịch công tác'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(Color c) => Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal:1), decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(children: [
        _legendItem(Colors.blue,'Task'),
        const SizedBox(width:12),
        _legendItem(Colors.purple,'Họp'),
        const SizedBox(width:12),
        _legendItem(Colors.orange,'Công tác'),
      ]),
    );
  }
  Widget _legendItem(Color c, String label) => Row(children:[_dot(c), const SizedBox(width:4), Text(label, style: const TextStyle(fontSize:12))]);

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(12,16,12,4),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
  Widget _emptyText(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal:12, vertical:4),
    child: Text(t, style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
  );

  List<Widget> _buildEventList(List<EventModel> list, UserModel? me, ApiService api) {
    return list.map((e) => Padding(
      padding: const EdgeInsets.symmetric(horizontal:12, vertical:6),
      child: EventListItemCard(
        event: e,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailPage(eventId: e.id)));
        },
        trailing: (me != null && e.participants.isNotEmpty)
            ? Builder(builder: (_) {
                final mine = e.participants.firstWhere(
                  (p) => p.userId == me.id,
                  orElse: () => e.participants.first,
                );
                if (mine.userId != me.id) return const SizedBox.shrink();
                final pid = mine.id;
                return Wrap(spacing: 8, children: [
                  OutlinedButton(
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
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu điều chỉnh')));
                      }
                    },
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                    child: const Text('Yêu cầu điều chỉnh'),
                  ),
                ]);
              })
            : null,
      ),
    )).toList();
  }

  Widget _taskTile(TaskModel t, UserModel? me) {
    // Determine if current user assigned
    final assigned = me != null && t.assignments.any((a) => a.userId == me.id);
    final progress = assigned
      ? t.assignments.firstWhere((a) => a.userId == me.id, orElse: () => t.assignments.first).progress
      : null;
    String status;
    if (t.assignments.isNotEmpty && t.assignments.every((a) => a.progress >= 100)) {
      status = 'Hoàn thành';
    } else if (t.assignments.any((a) => a.progress > 0)) {
      status = 'Đang thực hiện';
    } else {
      status = 'Cần làm';
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal:12, vertical:6),
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(t.title),
        subtitle: Text(status + (progress!=null? ' • ${progress.toString()}%':'') ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(task: t)));
        },
      ),
    );
  }
}
