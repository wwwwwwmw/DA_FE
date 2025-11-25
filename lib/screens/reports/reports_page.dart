import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ApiService>().currentUser;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lịch Họp'),
            Tab(text: 'Lịch Công Tác'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MeetingScheduleReport(isAdmin: isAdmin, user: user),
          BusinessTripReport(isAdmin: isAdmin, user: user),
        ],
      ),
    );
  }
}

class MeetingScheduleReport extends StatefulWidget {
  final bool isAdmin;
  final UserModel? user;

  const MeetingScheduleReport({
    super.key,
    required this.isAdmin,
    required this.user,
  });

  @override
  State<MeetingScheduleReport> createState() => _MeetingScheduleReportState();
}

class _MeetingScheduleReportState extends State<MeetingScheduleReport> {
  List<Map<String, dynamic>> _meetings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMeetings();
  }

  Future<void> _fetchMeetings() async {
    try {
      setState(() => _loading = true);
      final api = context.read<ApiService>();

      // Fetch all events first
      await api.fetchEvents();
      final allEvents = api.events;

      // Filter events for meetings
      final meetingEvents = allEvents
          .where(
            (event) =>
                event.type == 'meeting' ||
                event.title.toLowerCase().contains('họp'),
          )
          .toList();

      // Filter by department if not admin
      final filteredEvents = widget.isAdmin
          ? meetingEvents
          : meetingEvents
                .where(
                  (event) => event.departmentId == widget.user?.departmentId,
                )
                .toList();

      setState(() {
        _meetings = filteredEvents
            .map(
              (event) => {
                'id': event.id,
                'title': event.title,
                'startTime': event.startTime,
                'endTime': event.endTime,
                'room': event.roomName ?? 'Chưa chọn phòng',
                'department': event.departmentId ?? 'Tất cả phòng ban',
                'participants': event.participants.length,
                'status': event.status,
                'event': event, // Store full event object for actions
              },
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_meetings.isEmpty) {
      return const Center(child: Text('Không có lịch họp nào'));
    }

    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _meetings.length,
        itemBuilder: (context, index) {
          final meeting = _meetings[index];
          final event = meeting['event'];
          final isManager = widget.user?.role == 'manager';
          final isAdmin = widget.isAdmin;
          final status = meeting['status'];
          final hasStarted = event.startTime.isBefore(DateTime.now());

          // Permission logic:
          // Manager: can edit/delete pending events only
          // Admin: can edit/delete any event, but show warning for approved/started events
          final canEdit = (isManager && status == 'pending') || isAdmin;
          final canDelete = (isManager && status == 'pending') || isAdmin;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                meeting['title'] ?? 'Cuộc họp',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '📅 ${_formatDateTime(meeting['startTime'])} → ${_formatDateTime(meeting['endTime'])}',
                  ),
                  Text('🏢 Phòng: ${meeting['room']}'),
                  Text('🏛️ ${meeting['department']}'),
                  Text('👥 ${meeting['participants']} người tham gia'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(meeting['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(meeting['status']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (canEdit || canDelete)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editEvent(event);
                            break;
                          case 'delete':
                            _deleteEvent(event, status, hasStarted);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Sửa'),
                              ],
                            ),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Xóa',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Chưa xác định';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'pending':
        return 'Chờ duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return 'Chưa xác định';
    }
  }

  Future<void> _editEvent(dynamic event) async {
    // Show edit dialog similar to create event
    final titleCtrl = TextEditingController(text: event.title);
    final descCtrl = TextEditingController(text: event.description ?? '');
    DateTime? start = event.startTime;
    DateTime? end = event.endTime;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: const Text('Sửa Lịch Họp'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                          initialDate: start ?? now,
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(start ?? now),
                        );
                        if (t == null) return;
                        setS(
                          () => start = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          ),
                        );
                      },
                      child: Text(
                        start == null ? 'Chọn bắt đầu' : _fmtDT(start!),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                          initialDate: end ?? now,
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(end ?? now),
                        );
                        if (t == null) return;
                        setS(
                          () => end = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          ),
                        );
                      },
                      child: Text(end == null ? 'Chọn kết thúc' : _fmtDT(end!)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    try {
                      final api = context.read<ApiService>();
                      await api.updateEvent(
                        event.id,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        start: start,
                        end: end,
                      );
                      await _fetchMeetings(); // Refresh data
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cập nhật thành công!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi cập nhật: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(
    dynamic event,
    String status,
    bool hasStarted,
  ) async {
    final isAdmin = widget.isAdmin;
    String message = 'Bạn có chắc muốn xóa lịch họp này?';

    // Warning for admin when deleting approved or started events
    if (isAdmin && (status == 'approved' || hasStarted)) {
      if (hasStarted && status == 'approved') {
        message =
            '⚠️ Lịch họp đã được duyệt và đã bắt đầu. Bạn có chắc muốn xóa?';
      } else if (status == 'approved') {
        message = '⚠️ Lịch họp đã được duyệt. Bạn có chắc muốn xóa?';
      } else if (hasStarted) {
        message = '⚠️ Lịch họp đã bắt đầu. Bạn có chắc muốn xóa?';
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final api = context.read<ApiService>();
        await api.deleteEvent(event.id);
        await _fetchMeetings(); // Refresh data
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Xóa thành công!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
        }
      }
    }
  }

  String _fmtDT(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class BusinessTripReport extends StatefulWidget {
  final bool isAdmin;
  final UserModel? user;

  const BusinessTripReport({
    super.key,
    required this.isAdmin,
    required this.user,
  });

  @override
  State<BusinessTripReport> createState() => _BusinessTripReportState();
}

class _BusinessTripReportState extends State<BusinessTripReport> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchBusinessTrips();
  }

  Future<void> _fetchBusinessTrips() async {
    try {
      setState(() => _loading = true);
      final api = context.read<ApiService>();

      // Fetch all events first
      await api.fetchEvents();
      final allEvents = api.events;

      // Filter events for business trips
      final businessTripEvents = allEvents
          .where(
            (event) =>
                event.type == 'work' ||
                event.title.toLowerCase().contains('công tác'),
          )
          .toList();

      // Filter by department if not admin
      final filteredEvents = widget.isAdmin
          ? businessTripEvents
          : businessTripEvents
                .where(
                  (event) => event.departmentId == widget.user?.departmentId,
                )
                .toList();

      setState(() {
        _trips = filteredEvents
            .map(
              (event) => {
                'id': event.id,
                'title': event.title,
                'description': event.description ?? 'Không có mô tả',
                'startTime': event.startTime,
                'endTime': event.endTime,
                'department': event.departmentId ?? 'Tất cả phòng ban',
                'participants': event.participants
                    .map((p) => p.user?.name ?? 'Unknown')
                    .toList(),
                'status': event.status,
                'location': event.roomLocation ?? 'Chưa xác định',
                'event': event, // Store full event object for actions
              },
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trips.isEmpty) {
      return const Center(child: Text('Không có lịch công tác nào'));
    }

    return RefreshIndicator(
      onRefresh: _fetchBusinessTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          final trip = _trips[index];
          final event = trip['event'];
          final participants = trip['participants'] as List<String>;
          final isManager = widget.user?.role == 'manager';
          final isAdmin = widget.isAdmin;
          final status = trip['status'];
          final hasStarted = event.startTime.isBefore(DateTime.now());

          // Permission logic:
          // Manager: can edit/delete pending events only
          // Admin: can edit/delete any event, but show warning for approved/started events
          final canEdit = (isManager && status == 'pending') || isAdmin;
          final canDelete = (isManager && status == 'pending') || isAdmin;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip['title'] ?? 'Lịch công tác',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(trip['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(trip['status']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (canEdit || canDelete)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _editBusinessTrip(event);
                                break;
                              case 'delete':
                                _deleteBusinessTrip(event, status, hasStarted);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (canEdit)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Sửa'),
                                  ],
                                ),
                              ),
                            if (canDelete)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mô tả: ${trip['description']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📅 ${_formatDateTime(trip['startTime'])} → ${_formatDateTime(trip['endTime'])}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text('📍 ${trip['location']}'),
                  const SizedBox(height: 4),
                  Text('🏛️ ${trip['department']}'),
                  if (participants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Nhân viên tham gia:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: participants
                          .map(
                            (name) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Chưa xác định';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'pending':
        return 'Chờ duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return 'Chưa xác định';
    }
  }

  Future<void> _editBusinessTrip(dynamic event) async {
    final titleCtrl = TextEditingController(text: event.title);
    final descCtrl = TextEditingController(text: event.description ?? '');
    DateTime? start = event.startTime;
    DateTime? end = event.endTime;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: const Text('Sửa Lịch Công Tác'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                          initialDate: start ?? now,
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(start ?? now),
                        );
                        if (t == null) return;
                        setS(
                          () => start = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          ),
                        );
                      },
                      child: Text(
                        start == null ? 'Chọn bắt đầu' : _fmtDT(start!),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                          initialDate: end ?? now,
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(end ?? now),
                        );
                        if (t == null) return;
                        setS(
                          () => end = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          ),
                        );
                      },
                      child: Text(end == null ? 'Chọn kết thúc' : _fmtDT(end!)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    try {
                      final api = context.read<ApiService>();
                      await api.updateEvent(
                        event.id,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        start: start,
                        end: end,
                      );
                      await _fetchBusinessTrips(); // Refresh data
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cập nhật thành công!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi cập nhật: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteBusinessTrip(
    dynamic event,
    String status,
    bool hasStarted,
  ) async {
    final isAdmin = widget.isAdmin;
    String message = 'Bạn có chắc muốn xóa lịch công tác này?';

    // Warning for admin when deleting approved or started events
    if (isAdmin && (status == 'approved' || hasStarted)) {
      if (hasStarted && status == 'approved') {
        message =
            '⚠️ Lịch công tác đã được duyệt và đã bắt đầu. Bạn có chắc muốn xóa?';
      } else if (status == 'approved') {
        message = '⚠️ Lịch công tác đã được duyệt. Bạn có chắc muốn xóa?';
      } else if (hasStarted) {
        message = '⚠️ Lịch công tác đã bắt đầu. Bạn có chắc muốn xóa?';
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final api = context.read<ApiService>();
        await api.deleteEvent(event.id);
        await _fetchBusinessTrips(); // Refresh data
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Xóa thành công!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
        }
      }
    }
  }

  String _fmtDT(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
