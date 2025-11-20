// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';
import '../../models/department.dart';

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
  final _weightCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  String _status = 'todo';
  String _priority = 'normal';
  String _assignmentType = 'direct';
  int _capacity = 1;
  String? _departmentId;
  List<DepartmentModel> _departments = const [];
  String? _projectId;
  String? _assigneeId;
  List<Map<String,String>> _deptUsers = const [];

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
      if (t.weight != null) _weightCtrl.text = t.weight.toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = context.read<ApiService>();
      final me = api.currentUser;
      await api.fetchProjects();
      if (widget.preselectedProjectId != null) {
        _projectId = widget.preselectedProjectId;
      }
      if (me != null && me.role == 'admin') {
        await api.fetchDepartments();
        setState(() { _departments = api.departments; });
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
          _deptUsers = filtered.map((u) => {'id': u.id, 'name': u.name}).toList();
        });
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: DateTime(now.year-1), lastDate: DateTime(now.year+2), initialDate: (_start ?? now));
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() { if (isStart) { _start = dt; } else { _end = dt; } });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = context.read<ApiService>();
    if (widget.editing == null) {
      final task = await api.createTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        start: _start,
        end: _end,
        status: _status,
        priority: _priority,
        projectId: _projectId,
        assignmentType: _assignmentType,
        capacity: _capacity,
        departmentId: _departmentId,
        weight: _parseWeight(),
      );
      if (_assignmentType == 'direct' && _assigneeId != null) {
        await api.assignTask(task.id, _assigneeId!);
      }
    } else {
      await api.updateTask(
        widget.editing!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        start: _start,
        end: _end,
        status: _status,
        priority: _priority,
        projectId: _projectId,
        assignmentType: _assignmentType,
        capacity: _capacity,
        weight: _parseWeight(),
      );
      if (_assignmentType == 'direct' && _assigneeId != null) {
        await api.assignTask(widget.editing!.id, _assigneeId!);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  int? _parseWeight() {
    final raw = _weightCtrl.text.trim();
    if (raw.isEmpty) return null;
    final n = int.tryParse(raw);
    if (n == null) return null;
    if (n < 0 || n > 100) return null;
    return n;
  }

  Future<int> _sumExplicitWeights(String projectId, {String? excludingTaskId}) async {
    final api = context.read<ApiService>();
    final list = await api.listTasksForProject(projectId);
    int sum = 0;
    for (final t in list) {
      if (excludingTaskId != null && t.id == excludingTaskId) continue;
      if (t.weight != null) sum += t.weight!;
    }
    final newWeight = _parseWeight();
    if (newWeight != null) sum += newWeight;
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<ApiService>().currentUser;
    final canDelete = widget.editing != null && me != null && (
      me.role == 'admin' ||
      (me.role == 'manager' && (widget.editing!.departmentId == null || widget.editing!.departmentId == me.departmentId)) ||
      (widget.editing!.createdBy?.id == me.id)
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing==null? 'Thêm Công việc':'Sửa Công việc'),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx){
                  return AlertDialog(
                    title: const Text('Xóa nhiệm vụ'),
                    content: const Text('Bạn có chắc muốn xóa nhiệm vụ này?'),
                    actions: [
                      TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: const Text('Hủy')),
                      ElevatedButton(onPressed: ()=> Navigator.pop(ctx,true), child: const Text('Xóa')),
                    ],
                  );
                });
                if (ok == true) {
                  await context.read<ApiService>().deleteTask(widget.editing!.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            Text('Thông tin cơ bản', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
                  TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Tên công việc'), validator: (v)=> v==null||v.isEmpty? 'Không được để trống':null),
                  const SizedBox(height:12),
                  TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines:3),
                  const SizedBox(height:12),
                  Builder(builder: (ctx) {
                    final api = context.watch<ApiService>();
                    final items = api.projects
                        .map((p) => DropdownMenuItem<String>(value: p.id, child: Text(p.name)))
                        .toList();
                    final isLocked = widget.preselectedProjectId != null;
                    return DropdownButtonFormField<String>(
                      initialValue: _projectId,
                      items: items,
                      onChanged: isLocked ? null : (v) => setState(()=> _projectId = v),
                      validator: (v)=> v==null? 'Chọn dự án trước khi tạo công việc': null,
                      decoration: const InputDecoration(labelText: 'Dự án'),
                    );
                  }),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text('Chi tiết', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: ()=>_pickDate(true), child: Text(_start==null? 'Thời gian bắt đầu': _start.toString()))),
                    const SizedBox(width:8),
                    Expanded(child: OutlinedButton(onPressed: ()=>_pickDate(false), child: Text(_end==null? 'Thời gian kết thúc': _end.toString()))),
                  ]),
                  const SizedBox(height:12),
                  DropdownButtonFormField(initialValue: _priority, items: const [
                    DropdownMenuItem(value: 'low', child: Text('Thấp')),
                    DropdownMenuItem(value: 'normal', child: Text('Bình thường')),
                    DropdownMenuItem(value: 'high', child: Text('Cao')),
                    DropdownMenuItem(value: 'urgent', child: Text('Khẩn cấp')),
                  ], onChanged: (v)=> setState(()=> _priority = v as String), decoration: const InputDecoration(labelText: 'Độ ưu tiên')),
                  const SizedBox(height:12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Hình thức giao việc', border: InputBorder.none),
                      child: const Text('Trực tiếp (phân công)'),
                    ),
                  ),
                  const SizedBox(height:12),
                  DropdownButtonFormField<int>(
                    initialValue: _capacity,
                    items: List.generate(10, (i) => i+1).map((v) => DropdownMenuItem(value: v, child: Text('$v chỗ'))).toList(),
                    onChanged: (v) => setState(() { _capacity = v ?? 1; }),
                    decoration: const InputDecoration(labelText: 'Số chỗ (slots)'),
                  ),
                  const SizedBox(height:12),
                  TextFormField(
                    controller: _weightCtrl,
                    decoration: const InputDecoration(labelText: 'Trọng số (%) - để trống nếu tự phân bổ'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // optional
                      final n = int.tryParse(v.trim());
                      if (n == null) return 'Số không hợp lệ';
                      if (n < 0 || n > 100) return '0-100';
                      return null;
                    },
                    onChanged: (val) async {
                      if (_projectId != null) {
                        final sum = await _sumExplicitWeights(_projectId!, excludingTaskId: widget.editing?.id);
                        if (!mounted) return;
                        if (sum > 100) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảnh báo: Tổng trọng số vượt 100%'), backgroundColor: Colors.red));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (ctx){
                    final me = context.read<ApiService>().currentUser;
                    if (me == null || (me.role != 'manager' && me.role != 'admin')) return const SizedBox.shrink();
                    return DropdownButtonFormField<String>(
                      initialValue: _assigneeId,
                      items: _deptUsers.map((u) => DropdownMenuItem(value: u['id']!, child: Text(u['name']!))).toList(),
                      onChanged: (v) => setState(()=> _assigneeId = v),
                      decoration: const InputDecoration(labelText: 'Giao cho (phòng ban)'),
                    );
                  }),
                  const SizedBox(height:12),
                  Builder(builder: (ctx) {
                    final api = context.read<ApiService>();
                    final me = api.currentUser;
                    if (me != null && me.role == 'admin') {
                      return DropdownButtonFormField<String>(
                        initialValue: _departmentId,
                        items: _departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                        onChanged: (v) => setState(() => _departmentId = v),
                        decoration: const InputDecoration(labelText: 'Phòng ban (chỉ admin)'),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ]),
              ),
            ),
            const SizedBox(height:24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Lưu')),
            )
          ]),
        ),
      ),
    );
  }
}
