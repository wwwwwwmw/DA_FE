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
  double? _weight;

  String? _projectId;
  String? _assigneeId;
  List<String> _selectedAssignees = [];
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
      _weight = t.weight?.toDouble();
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

    // Pre-check schedule conflict (only when creating & direct assignment)
    if (widget.editing == null &&
        _assignmentType == 'direct' &&
        _assigneeId != null &&
        (_start != null || _end != null)) {
      final startForCheck = _start ?? _end; // fallback if only end chosen
      final endForCheck = _end ?? _start; // if only start chosen
      if (startForCheck != null) {
        try {
          final r = await api.checkUserBusinessTripConflict(
            userId: _assigneeId!,
            start: startForCheck,
            end: endForCheck,
          );
          if (r['hasConflict'] == true) {
            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('⚠️ Trùng lịch công tác'),
                  content: Text(
                    r['message'] ??
                        'Người được phân công có lịch công tác trùng. Vui lòng chỉnh sửa thời gian hoặc chọn người khác.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Đã hiểu'),
                    ),
                  ],
                ),
              );
            }
            return; // STOP: không tạo task
          }
        } catch (_) {
          // Nếu endpoint lỗi, vẫn tiếp tục (không chặn) để không gây kẹt luồng
        }
      }
    }

    try {
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
          weight: _weight?.round(),
        );
        // Assign multiple users if selected
        if (_assignmentType == 'direct') {
          for (String assigneeId in _selectedAssignees) {
            try {
              await api.assignTask(task.id, assigneeId);
            } catch (e) {
              // Nếu assign trả 409 (task full/đã tồn tại), vẫn giữ task và chỉ báo lỗi
              if (e.toString().contains('409')) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Không thể phân công cho ${_deptUsers.firstWhere((u) => u['id'] == assigneeId, orElse: () => {'name': 'người dùng'})['name']}: xung đột hoặc đã đầy.',
                      ),
                    ),
                  );
                }
              } else {
                rethrow;
              }
            }
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Công việc "${_titleCtrl.text.trim()}" đã tạo'),
            ),
          );
        }
      } else {
        // Pre-check on edit if changing assignment/time
        if (_assignmentType == 'direct' &&
            _selectedAssignees.isNotEmpty &&
            (_start != null || _end != null)) {
          final startForCheck = _start ?? _end;
          final endForCheck = _end ?? _start;
          if (startForCheck != null) {
            for (String assigneeId in _selectedAssignees) {
              try {
                final r = await api.checkUserBusinessTripConflict(
                  userId: assigneeId,
                  start: startForCheck,
                  end: endForCheck,
                );
                if (r['hasConflict'] == true) {
                  if (mounted) {
                    final userName = _deptUsers.firstWhere(
                      (u) => u['id'] == assigneeId,
                      orElse: () => {'name': 'người dùng'},
                    )['name'];
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: const Text('⚠️ Trùng lịch công tác'),
                        content: Text(
                          '$userName: ${r['message'] ?? 'có lịch công tác trùng. Vui lòng chỉnh sửa.'}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Đã hiểu'),
                          ),
                        ],
                      ),
                    );
                  }
                  return; // STOP update
                }
              } catch (_) {}
            }
          }
        }
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
          weight: _weight?.round(),
        );
        // Assign multiple users for update
        if (_assignmentType == 'direct') {
          for (String assigneeId in _selectedAssignees) {
            try {
              await api.assignTask(widget.editing!.id, assigneeId);
            } catch (_) {}
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Công việc "${_titleCtrl.text.trim()}" đã cập nhật',
              ),
            ),
          );
        }
      }

      try {
        await api.fetchTasks();
      } catch (_) {}
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        title: Text(
          widget.editing == null ? 'Nhiệm vụ mới' : 'Chỉnh sửa nhiệm vụ',
        ),
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
                  hintText: 'Ví dụ: Hoàn thiện slide thuyết trình',
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
                      title: 'Ngày bắt đầu',
                      value: _start == null
                          ? 'Chọn thời gian'
                          : _start.toString(),
                      onTap: () => _pickDate(true),
                    ),
                    const Divider(height: 1),
                    _RowItem(
                      icon: Icons.calendar_today_outlined,
                      title: 'Ngày kết thúc',
                      value: _end == null ? 'Chọn thời gian' : _end.toString(),
                      onTap: () => _pickDate(false),
                    ),
                    const Divider(height: 1),
                    _RowItem(
                      icon: Icons.people_alt_outlined,
                      title: 'Giao cho',
                      value: _selectedAssignees.isEmpty
                          ? 'Chọn người thực hiện'
                          : '${_selectedAssignees.length} người được chọn',
                      onTap: () async {
                        await _pickMultipleAssignees(context);
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
                          title: 'Dự án',
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
                'Mô tả',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Thêm ghi chú hoặc chi tiết...',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ưu tiên',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'low', label: Text('Thấp')),
                  ButtonSegment(value: 'normal', label: Text('Trung bình')),
                  ButtonSegment(value: 'high', label: Text('Cao')),
                ],
                selected: {_priority == 'urgent' ? 'high' : _priority},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 16),
              const Text(
                'Trọng số (% công việc)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _weight?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: 30 (cho 30%)',
                  suffixText: '%',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  setState(() => _weight = parsed);
                },
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final num = double.tryParse(v);
                    if (num == null || num < 0 || num > 100) {
                      return 'Vui lòng nhập số từ 0-100';
                    }
                  }
                  return null;
                },
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
                  child: Text(widget.editing == null ? 'Tạo nhiệm vụ' : 'Lưu'),
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

  Future<void> _pickMultipleAssignees(BuildContext context) async {
    if (_deptUsers.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Chọn người thực hiện',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: _deptUsers.map((u) {
                    final isSelected = _selectedAssignees.contains(u['id']);
                    return CheckboxListTile(
                      title: Text(u['name'] ?? ''),
                      value: isSelected,
                      onChanged: (checked) {
                        setModalState(() {
                          if (checked == true) {
                            if (!_selectedAssignees.contains(u['id'])) {
                              _selectedAssignees.add(u['id']!);
                            }
                          } else {
                            _selectedAssignees.remove(u['id']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Update main state
                        Navigator.pop(c);
                      },
                      child: const Text('Xác nhận'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
