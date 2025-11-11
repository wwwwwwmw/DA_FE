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

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final eventsByDay = <DateTime, List<EventModel>>{};
    for (final e in api.events) {
      final day = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      eventsByDay.putIfAbsent(day, () => []).add(e);
    }

    List<EventModel> selectedEvents = [];
    final sel = _selectedDay ?? DateTime.now();
    final selKey = DateTime(sel.year, sel.month, sel.day);
    selectedEvents = eventsByDay[selKey] ?? [];

    return Column(
      children: [
        TableCalendar<EventModel>(
          firstDay: DateTime.utc(2010, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return eventsByDay[key] ?? [];
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => api.fetchEvents(),
            child: ListView.builder(
              itemCount: selectedEvents.length,
              itemBuilder: (ctx, i) {
                final e = selectedEvents[i];
                return ListTile(
                  title: Text(e.title),
                  subtitle: Text('${DateFormat('HH:mm').format(e.startTime)} - ${DateFormat('HH:mm').format(e.endTime)} • ${e.status}'),
                );
              },
            ),
          ),
        )
      ],
    );
  }
}
