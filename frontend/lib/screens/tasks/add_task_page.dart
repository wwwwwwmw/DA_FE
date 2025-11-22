// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';

class AddTaskPage extends StatefulWidget {
  final TaskModel? editing;
  final String? preselectedProjectId;
  const AddTaskPage({super.key, this.editing, this.preselectedProjectId});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  String _status = 'todo';
  String _priority = 'normal';
  String _assignmentType = 'direct';
  int _capacity = 1;
  String? _departmentId;

  String? _projectId;
  String? _assigneeId;
  List<Map<String, String>> _deptUsers = const [];

  @override
  void initState() {
    super.initState();
    final t = widget.editing;
    if (t != null) {
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description ?? '';
      _start = t.startTime;
      _end = t.endTime;
      _status = t.status;
      _priority = t.priority;
      _assignmentType = t.assignmentType;
      _capacity = t.capacity;
      _departmentId = t.departmentId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = context.read<ApiService>();
      final me = api.currentUser;
      await api.fetchProjects();
      if (widget.preselectedProjectId != null) {
        _projectId = widget.preselectedProjectId;
      }
      if (me != null && me.role == 'admin') {
      } else if (me != null && me.role == 'manager') {
        _departmentId = me.departmentId;
      }
      if (widget.editing != null && widget.editing!.project != null) {
        _projectId = widget.editing!.project!.id;
      }
      if (me != null && (me.role == 'manager' || me.role == 'admin')) {
        final users = await api.listUsers(limit: 200, offset: 0);
        final filtered = (me.role == 'manager' && me.departmentId != null)
            ? users.where((u) => u.departmentId == me.departmentId).toList()
            : users;
        setState(() {
          _deptUsers = filtered
              .map((u) => {'id': u.id, 'name': u.name})
              .toList();
        });
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: (_start ?? now),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<ApiService>();
    if (widget.editing == null) {
      final task = await api.createTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        start: _start,
        end: _end,
        status: _status,
        priority: _priority,
        projectId: _projectId,
        assignmentType: _assignmentType,
        capacity: _capacity,
        departmentId: _departmentId,
      );
      if (_assignmentType == 'direct' && _assigneeId != null) {
        await api.assignTask(task.id, _assigneeId!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Công việc "${_titleCtrl.text.trim()}" đã tạo')),
      );
    } else {
      await api.updateTask(
        widget.editing!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        start: _start,
        end: _end,
        status: _status,
        priority: _priority,
        projectId: _projectId,
        assignmentType: _assignmentType,
        capacity: _capacity,
      );
      if (_assignmentType == 'direct' && _assigneeId != null) {
        await api.assignTask(widget.editing!.id, _assigneeId!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Công việc "${_titleCtrl.text.trim()}" đã cập nhật'),
        ),
      );
    }
    // Refresh list data so previous screens reflect changes
    try {
      await api.fetchTasks();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<ApiService>().currentUser;
    final canDelete =
        widget.editing != null &&
        me != null &&
        (me.role == 'admin' ||
            (me.role == 'manager' &&
                (widget.editing!.departmentId == null ||
                    widget.editing!.departmentId == me.departmentId)) ||
            (widget.editing!.createdBy?.id == me.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'New Task' : 'Edit Task'),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Xóa nhiệm vụ'),
                      content: const Text('Bạn có chắc muốn xóa nhiệm vụ này?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    );
                  },
                );
                if (ok == true) {
                  await context.read<ApiService>().deleteTask(
                    widget.editing!.id,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g., Finalize presentation slides',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _RowItem(
                      icon: Icons.play_circle_outline,
                      title: 'Start Date',
                      value: _start == null
                          ? 'Chọn thời gian'
                          : _start.toString(),
                      onTap: () => _pickDate(true),
                    ),
                    const Divider(height: 1),
                    _RowItem(
                      icon: Icons.calendar_today_outlined,
                      title: 'Due Date',
                      value: _end == null ? 'Chọn thời gian' : _end.toString(),
                      onTap: () => _pickDate(false),
                    ),
                    const Divider(height: 1),
                    _RowItem(
                      icon: Icons.person_add_alt,
                      title: 'Assign to',
                      value: _assigneeId == null
                          ? 'Chọn người'
                          : (_deptUsers.firstWhere(
                                  (e) => e['id'] == _assigneeId,
                                  orElse: () => {'name': 'Đã chọn'},
                                )['name'] ??
                                'Đã chọn'),
                      onTap: () async {
                        final v = await _pickAssignee(context);
                        if (v != null) setState(() => _assigneeId = v);
                      },
                    ),
                    const Divider(height: 1),
                    Builder(
                      builder: (ctx) {
                        final api = context.watch<ApiService>();
                        final isLocked = widget.preselectedProjectId != null;
                        String name = 'Chọn dự án';
                        if (_projectId != null) {
                          try {
                            name = api.projects
                                .firstWhere((p) => p.id == _projectId)
                                .name;
                          } catch (_) {
                            name = 'Chọn dự án';
                          }
                        }
                        return _RowItem(
                          icon: Icons.folder_open,
                          title: 'Project',
                          value: name,
                          onTap: isLocked
                              ? null
                              : () async {
                                  final v = await _pickProject(context);
                                  if (v != null) setState(() => _projectId = v);
                                },
                        );
                      },
                    ),
                    // Removed explicit Remind Me row (reminders scheduled automatically)
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add notes or details...',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Priority',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'low', label: Text('Low')),
                  ButtonSegment(value: 'normal', label: Text('Medium')),
                  ButtonSegment(value: 'high', label: Text('High')),
                ],
                selected: {_priority == 'urgent' ? 'high' : _priority},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_projectId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng chọn dự án')),
                      );
                      return;
                    }
                    await _save();
                  },
                  child: Text(widget.editing == null ? 'Create Task' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickProject(BuildContext context) async {
    final api = context.read<ApiService>();
    if (api.projects.isEmpty) return null;
    return showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          children: api.projects
              .map(
                (p) => ListTile(
                  title: Text(p.name),
                  onTap: () => Navigator.pop(c, p.id),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<String?> _pickAssignee(BuildContext context) async {
    if (_deptUsers.isEmpty) return null;
    return showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          children: _deptUsers
              .map(
                (u) => ListTile(
                  title: Text(u['name'] ?? ''),
                  onTap: () => Navigator.pop(c, u['id']),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  const _RowItem({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(value, style: const TextStyle(color: Colors.black54)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
