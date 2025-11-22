// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../models/room.dart';
import '../reports/event_report_page.dart';
import '../../services/api_service.dart';
import '../../models/event.dart';

class EventsAdminTab extends StatefulWidget {
  const EventsAdminTab({super.key});
  @override
  State<EventsAdminTab> createState() => _EventsAdminTabState();
}

class _EventsAdminTabState extends State<EventsAdminTab> {
  bool _loading = false;
  String _mode = 'month'; // 'month' | 'year' | 'range'
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context.read<ApiService>().fetchEvents();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreate() async {
    final api = context.read<ApiService>();
    if (api.departments.isEmpty) await api.fetchDepartments();
    if (api.rooms.isEmpty) await api.fetchRooms();
    // Users (for selecting participants in work trip)
    final users = await api.listUsers(limit: 500);

    DateTime? start;
    DateTime? end;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String eventType = 'work'; // 'work' | 'meeting'
    final Set<String> selectedDeptIds = {};
    final Set<String> selectedParticipantIds = {};
    String? selectedRoomId;
    Future<void> pickStart() async {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: DateTime.now(),
      );
      if (date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null)
        start = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      setState(() {});
    }

    Future<void> pickEnd() async {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: start ?? DateTime.now(),
      );
      if (date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null)
        end = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      setState(() {});
    }

    List<RoomModel> availableRooms() {
      if (start == null || end == null) return api.rooms;
      return api.rooms.where((r) {
        final overlap = api.events.any(
          (ev) =>
              ev.type == 'meeting' &&
              ev.roomId == r.id &&
              ev.startTime.isBefore(end!) &&
              ev.endTime.isAfter(start!),
        );
        return !overlap;
      }).toList();
    }

    Future<void> selectDepartments(StateSetter setDialog) async {
      await showDialog(
        context: context,
        builder: (c) {
          return StatefulBuilder(
            builder: (c, setInner) {
              return AlertDialog(
                title: const Text('Chọn phòng ban'),
                content: SizedBox(
                  width: 400,
                  child: ListView(
                    children: api.departments
                        .map(
                          (d) => CheckboxListTile(
                            value: selectedDeptIds.contains(d.id),
                            title: Text(d.name),
                            onChanged: (v) {
                              if (v == true) {
                                selectedDeptIds.add(d.id);
                              } else {
                                selectedDeptIds.remove(d.id);
                              }
                              // Rebuild both inner dialog (to show tick) and outer dialog (to update count)
                              setInner(() {});
                              setDialog(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Xong'),
                  ),
                ],
              );
            },
          );
        },
      );
      // Ensure outer dialog reflects latest selections after closing
      setDialog(() {});
    }

    Future<void> selectParticipants(StateSetter setDialog) async {
      final filtered = users
          .where(
            (u) =>
                u.departmentId != null &&
                selectedDeptIds.contains(u.departmentId),
          )
          .toList();
      await showDialog(
        context: context,
        builder: (c) {
          return StatefulBuilder(
            builder: (c, setInner) {
              return AlertDialog(
                title: const Text('Chọn nhân viên'),
                content: SizedBox(
                  width: 400,
                  child: ListView(
                    children: filtered
                        .map(
                          (u) => CheckboxListTile(
                            value: selectedParticipantIds.contains(u.id),
                            title: Text('${u.name} (${u.email})'),
                            onChanged: (v) {
                              if (v == true) {
                                selectedParticipantIds.add(u.id);
                              } else {
                                selectedParticipantIds.remove(u.id);
                              }
                              setInner(() {});
                              setDialog(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Xong'),
                  ),
                ],
              );
            },
          );
        },
      );
      setDialog(() {});
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setStateDialog) {
          return AlertDialog(
            title: const Text('Tạo lịch'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Loại:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: eventType,
                        items: const [
                          DropdownMenuItem(
                            value: 'work',
                            child: Text('Lịch công tác'),
                          ),
                          DropdownMenuItem(
                            value: 'meeting',
                            child: Text('Lịch họp'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            eventType = v;
                            setStateDialog(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          start == null
                              ? 'Chọn bắt đầu'
                              : 'Bắt đầu: ${start!.toLocal()}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await pickStart();
                          setStateDialog(() {});
                        },
                        child: const Text('Chọn'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          end == null
                              ? 'Chọn kết thúc'
                              : 'Kết thúc: ${end!.toLocal()}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await pickEnd();
                          setStateDialog(() {});
                        },
                        child: const Text('Chọn'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Phòng ban đã chọn: ${selectedDeptIds.length}',
                        ),
                      ),
                      TextButton(
                        onPressed: () => selectDepartments(setStateDialog),
                        child: const Text('Chọn phòng ban'),
                      ),
                    ],
                  ),
                  if (eventType == 'work') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Nhân viên đã chọn: ${selectedParticipantIds.length}',
                          ),
                        ),
                        TextButton(
                          onPressed: selectedDeptIds.isEmpty
                              ? null
                              : () => selectParticipants(setStateDialog),
                          child: const Text('Chọn nhân viên'),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Phòng họp:'),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: selectedRoomId,
                          hint: const Text('Chọn phòng'),
                          items: availableRooms()
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            selectedRoomId = v;
                            setStateDialog(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true &&
        titleCtrl.text.trim().isNotEmpty &&
        start != null &&
        end != null) {
      if (!context.mounted) return;
      // Validate participants/room
      if (eventType == 'work' && selectedParticipantIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chọn ít nhất 1 nhân viên cho lịch công tác'),
          ),
        );
        return;
      }
      if (eventType == 'meeting' && selectedRoomId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chọn phòng họp trống')));
        return;
      }
      if (eventType == 'meeting') {
        EventModel? conflict;
        for (final ev in api.events) {
          if (ev.type == 'meeting' &&
              ev.roomId == selectedRoomId &&
              ev.startTime.isBefore(end!) &&
              ev.endTime.isAfter(start!)) {
            conflict = ev;
            break;
          }
        }
        if (conflict != null) {
          final cStart = _fmtDT(conflict.startTime.toLocal());
          final cEnd = _fmtDT(conflict.endTime.toLocal());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã có người đặt phòng họp từ $cStart đến $cEnd. Vui lòng chọn giờ khác.',
              ),
            ),
          );
          return;
        }
      }
      try {
        await context.read<ApiService>().createEvent(
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
          start: start,
          end: end,
          participantIds: eventType == 'work'
              ? selectedParticipantIds.toList()
              : null,
          roomId: eventType == 'meeting' ? selectedRoomId : null,
          departmentIds: selectedDeptIds.isNotEmpty
              ? selectedDeptIds.toList()
              : null,
          type: eventType,
        );
        if (!mounted) return;
        await context.read<ApiService>().fetchEvents();
      } on DioException catch (e) {
        if (!mounted) return;
        final msg = (e.response?.statusCode == 400)
            ? 'Không tạo được lịch: dữ liệu không hợp lệ hoặc trùng thời gian.'
            : 'Lỗi tạo lịch: ${e.message}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _showEdit(EventModel ev) async {
    DateTime? start = ev.startTime;
    DateTime? end = ev.endTime;
    final titleCtrl = TextEditingController(text: ev.title);
    final descCtrl = TextEditingController(text: ev.description ?? '');
    String? selectedRoomId = ev.type == 'meeting' ? ev.roomId : null;
    List<RoomModel> availableRoomsEdit() {
      if (start == null || end == null) return context.read<ApiService>().rooms;
      final api = context.read<ApiService>();
      return api.rooms.where((r) {
        final overlap = api.events.any(
          (other) =>
              other.id != ev.id &&
              other.type == 'meeting' &&
              other.roomId == r.id &&
              other.startTime.isBefore(end!) &&
              other.endTime.isAfter(start!),
        );
        return !overlap;
      }).toList();
    }

    Future<void> pickStart() async {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: start ?? DateTime.now(),
      );
      if (date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(start ?? DateTime.now()),
      );
      if (time != null)
        start = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      setState(() {});
    }

    Future<void> pickEnd() async {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: end ?? start ?? DateTime.now(),
      );
      if (date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(end ?? DateTime.now()),
      );
      if (time != null)
        end = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      setState(() {});
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setStateDialog) {
          return AlertDialog(
            title: Text(ev.type == 'meeting' ? 'Sửa lịch họp' : 'Sửa lịch'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          start == null
                              ? 'Chọn bắt đầu'
                              : 'Bắt đầu: ${_fmtDT(start!.toLocal())}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await pickStart();
                          setStateDialog(() {});
                        },
                        child: const Text('Chọn'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          end == null
                              ? 'Chọn kết thúc'
                              : 'Kết thúc: ${_fmtDT(end!.toLocal())}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await pickEnd();
                          setStateDialog(() {});
                        },
                        child: const Text('Chọn'),
                      ),
                    ],
                  ),
                  if (ev.type == 'meeting') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Phòng họp:'),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: selectedRoomId,
                          hint: const Text('Chọn phòng'),
                          items: availableRoomsEdit()
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(r.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            selectedRoomId = v;
                            setStateDialog(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Cập nhật'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true &&
        titleCtrl.text.trim().isNotEmpty &&
        start != null &&
        end != null) {
      if (!context.mounted) return;
      if (ev.type == 'meeting') {
        if (selectedRoomId == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Chọn phòng họp trống')));
          return;
        }
        final api = context.read<ApiService>();
        EventModel? conflict;
        for (final other in api.events) {
          if (other.id != ev.id &&
              other.type == 'meeting' &&
              other.roomId == selectedRoomId &&
              other.startTime.isBefore(end!) &&
              other.endTime.isAfter(start!)) {
            conflict = other;
            break;
          }
        }
        if (conflict != null) {
          final cStart = _fmtDT(conflict.startTime.toLocal());
          final cEnd = _fmtDT(conflict.endTime.toLocal());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã có người đặt phòng họp từ $cStart đến $cEnd. Vui lòng chọn giờ khác.',
              ),
            ),
          );
          return;
        }
      }
      try {
        await context.read<ApiService>().updateEvent(
          ev.id,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
          start: start,
          end: end,
          roomId: selectedRoomId,
        );
        if (!mounted) return;
        await context.read<ApiService>().fetchEvents();
      } on DioException catch (e) {
        if (!mounted) return;
        final msg = (e.response?.statusCode == 400)
            ? 'Không cập nhật được: dữ liệu không hợp lệ hoặc trùng thời gian.'
            : 'Lỗi cập nhật: ${e.message}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _delete(EventModel ev) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa lịch'),
        content: Text('Bạn có chắc chắn xóa "${ev.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (!context.mounted) return;
      await context.read<ApiService>().deleteEvent(ev.id);
    }
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ApiService>();
    final filtered = _filteredEvents(service.events);
    final now = DateTime.now();
    final upcoming = <EventModel>[];
    final past = <EventModel>[];
    for (final e in filtered) {
      if (e.endTime.isAfter(now)) {
        upcoming.add(e);
      } else {
        past.add(e);
      }
    }
    upcoming.sort(
      (a, b) => a.startTime.compareTo(b.startTime),
    ); // soonest first
    past.sort(
      (a, b) => b.startTime.compareTo(a.startTime),
    ); // most recent past first
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 112, top: 8),
            children: [
              _buildFilterBar(context),
              if (upcoming.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Sắp diễn ra',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                for (final ev in upcoming) _eventCard(ev),
              ],
              if (past.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Đã qua',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                for (final ev in past) _eventCard(ev),
              ],
              if (upcoming.isEmpty && past.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Không có lịch trong khoảng này')),
                ),
            ],
          ),
        ),
        if (_loading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'fab-admin-events-report',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventReportPage()),
                ),
                icon: const Icon(Icons.insights),
                label: const Text('Báo cáo'),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'fab-admin-events-create',
                onPressed: _showCreate,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _eventCard(EventModel ev) {
    final startStr = _fmtDT(ev.startTime.toLocal());
    final endStr = _fmtDT(ev.endTime.toLocal());
    final api = context.read<ApiService>();
    String? roomName;
    if (ev.type == 'meeting' && ev.roomId != null) {
      for (final r in api.rooms) {
        if (r.id == ev.roomId) {
          roomName = r.name;
          break;
        }
      }
      roomName ??= 'Không rõ';
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text(ev.title),
        subtitle: Text(
          roomName == null
              ? '$startStr → $endStr\nTrạng thái: ${ev.status}'
              : '$startStr → $endStr\nPhòng: $roomName\nTrạng thái: ${ev.status}',
        ),
        onTap: () => _showEdit(ev),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showEdit(ev);
            if (v == 'delete') _delete(ev);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }

  String _fmtDT(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Thời gian:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _mode,
                items: const [
                  DropdownMenuItem(value: 'month', child: Text('Theo tháng')),
                  DropdownMenuItem(value: 'year', child: Text('Theo năm')),
                  DropdownMenuItem(
                    value: 'range',
                    child: Text('Khoảng thời gian'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _mode = v;
                    if (_mode != 'range') _range = null;
                  });
                },
              ),
              const SizedBox(width: 16),
              const Text('Năm:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _year,
                items: [
                  for (
                    var y = DateTime.now().year - 4;
                    y <= DateTime.now().year + 1;
                    y++
                  )
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _year = v);
                },
              ),
            ],
          ),
          if (_mode == 'month') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Tháng:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _month,
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _month = v);
                  },
                ),
              ],
            ),
          ] else if (_mode == 'range') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _range == null
                        ? 'Chọn khoảng thời gian'
                        : '${_fmtDate(_range!.start)} → ${_fmtDate(_range!.end)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                      initialDateRange: _range,
                    );
                    if (picked != null) {
                      setState(() => _range = picked);
                    }
                  },
                  child: const Text('Chọn'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<EventModel> _filteredEvents(List<EventModel> events) {
    if (events.isEmpty) return events;

    DateTimeRange effectiveRange;
    if (_mode == 'range' && _range != null) {
      effectiveRange = _range!;
    } else if (_mode == 'year') {
      effectiveRange = DateTimeRange(
        start: DateTime(_year, 1, 1),
        end: DateTime(_year, 12, 31, 23, 59, 59),
      );
    } else {
      // month mode
      final start = DateTime(_year, _month, 1);
      final end = DateTime(
        _year,
        _month + 1,
        1,
      ).subtract(const Duration(seconds: 1));
      effectiveRange = DateTimeRange(start: start, end: end);
    }

    bool overlaps(EventModel e) {
      return !(e.endTime.isBefore(effectiveRange.start) ||
          e.startTime.isAfter(effectiveRange.end));
    }

    return events.where(overlaps).toList();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
