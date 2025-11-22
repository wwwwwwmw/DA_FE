import 'package:flutter/material.dart';
import 'package:frontend/models/project.dart';
import '../../models/task.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/task_list_item_card.dart';
import 'task_detail_page.dart';
import 'add_task_page.dart';
import 'projects_page.dart';
import 'task_status_page.dart';

class HomeTasksPage extends StatefulWidget {
  const HomeTasksPage({super.key});

  @override
  State<HomeTasksPage> createState() => _HomeTasksPageState();
}

class _HomeTasksPageState extends State<HomeTasksPage> {
  String? _selectedProjectId;
  String _search = '';
  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    api.fetchTasks();
    api.fetchProjects();
    api.fetchTaskStats();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final tasks = api.tasks;
    // Tính trạng thái theo tiến độ assignments thay vì field tĩnh
    int todo = 0, inProgress = 0, completed = 0;
    for (final t in tasks) {
      final asg = t.assignments;
      final derived = (asg.isNotEmpty && asg.every((a) => a.progress >= 100))
          ? 'completed'
          : (asg.any((a) => a.progress > 0 && a.progress < 100)
                ? 'in_progress'
                : 'todo');
      if (derived == 'completed')
        completed++;
      else if (derived == 'in_progress')
        inProgress++;
      else
        todo++;
    }
    final stats = {
      'todo': todo,
      'in_progress': inProgress,
      'completed': completed,
    };
    final total = todo + inProgress + completed;
    final completedPct = total == 0 ? 0.0 : completed / total;
    // final cs = Theme.of(context).colorScheme; // reserved for future theming

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tiến độ ${(completedPct * 100).round()}%',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TaskStatusPage(),
                        ),
                      ),
                      icon: const Icon(Icons.pie_chart_outline),
                      tooltip: 'Trạng thái',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _CompactStats(stats: stats),
            const SizedBox(height: 24),
            // Filters
            _FilterBar(
              projects: api.projects,
              selectedProjectId: _selectedProjectId,
              onProjectChanged: (id) async {
                setState(() => _selectedProjectId = id);
                await api.fetchTasks(projectId: id);
              },
              search: _search,
              onSearchChanged: (v) => setState(() {
                _search = v;
              }),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nhiệm vụ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._buildGroupedTasks(tasks),
            if (tasks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Chưa có task'),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton:
          (api.currentUser != null && api.currentUser!.role != 'employee')
          ? _FabMenu(
              onAddTask: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTaskPage()),
                );
              },
              onProjects: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProjectsPage()),
                );
              },
              onAddWorkEvent: () async {
                await _createWorkEventDialog(context);
              },
            )
          : null,
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng';
    if (h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  List<Widget> _buildGroupedTasks(List<TaskModel> all) {
    // Filter by search and selected project
    Iterable<TaskModel> list = all;
    if (_selectedProjectId != null) {
      list = list.where((t) => t.project?.id == _selectedProjectId);
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) => t.title.toLowerCase().contains(q));
    }
    // Group by day using due date if present, else start date
    final map = <DateTime, List<TaskModel>>{};
    for (final t in list) {
      final base = t.endTime ?? t.startTime;
      if (base == null) continue;
      final key = DateTime(base.year, base.month, base.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    // Sort from nearest to farthest relative to today
    final now = DateTime.now();
    int dist(DateTime d) => (DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays).abs();
    final days = map.keys.toList()
      ..sort((a, b) {
        final da = dist(a), db = dist(b);
        if (da != db) return da.compareTo(db);
        return a.compareTo(b); // tie-breaker chronological
      });
    final widgets = <Widget>[];
    for (final d in days) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _fmtDate(d),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      for (final t in map[d]!) {
        widgets.add(
          TaskListItemCard(
            task: t,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaskDetailPage(task: t)),
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _CompactStats extends StatelessWidget {
  final Map<String, int> stats;
  const _CompactStats({required this.stats});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _mini('Hoàn thành', stats['completed']!, cs.tertiary),
        const SizedBox(width: 8),
        _mini('Đang làm', stats['in_progress']!, cs.primary),
        const SizedBox(width: 8),
        _mini('Cần làm', stats['todo']!, cs.secondary),
      ],
    );
  }

  Widget _mini(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed old progress card dot style in favor of compact stat blocks

// _TaskItem removed in favor of reusable TaskListItemCard

class _FilterBar extends StatelessWidget {
  final List<ProjectModel> projects;
  final String? selectedProjectId;
  final ValueChanged<String?> onProjectChanged;
  final String search;
  final ValueChanged<String> onSearchChanged;
  const _FilterBar({
    required this.projects,
    required this.selectedProjectId,
    required this.onProjectChanged,
    required this.search,
    required this.onSearchChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedProjectId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tất cả dự án'),
                  ),
                  ...projects.map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ),
                ],
                onChanged: onProjectChanged,
                decoration: const InputDecoration(labelText: 'Dự án'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: search,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Tìm task',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _createWorkEventDialog(BuildContext context) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  DateTime? start;
  DateTime? end;
  String? departmentId;
  String? participantId;
  final api = context.read<ApiService>();
  final me = api.currentUser;
  List<Map<String, String>> deptUsers = [];
  if (me != null && (me.role == 'manager' || me.role == 'admin')) {
    final users = await api.listUsers(limit: 200, offset: 0);
    final filtered = (me.role == 'manager' && me.departmentId != null)
        ? users.where((u) => u.departmentId == me.departmentId).toList()
        : users;
    deptUsers = filtered.map((u) => {'id': u.id, 'name': u.name}).toList();
  }
  if (me != null && me.role == 'manager') {
    departmentId = me.departmentId;
  } else if (me != null && me.role == 'admin') {
    await api.fetchDepartments();
  }
  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Tạo Lịch công tác'),
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
                        initialDate: now,
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.now(),
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
                        initialDate: now,
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.now(),
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
                  if (me != null && me.role == 'admin')
                    DropdownButtonFormField<String>(
                      value: departmentId,
                      hint: const Text('Phòng ban'),
                      items: api.departments
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setS(() => departmentId = v),
                    ),
                  if (deptUsers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: participantId,
                      hint: const Text('Người tham gia (tùy chọn)'),
                      items: deptUsers
                          .map(
                            (u) => DropdownMenuItem(
                              value: u['id'],
                              child: Text(u['name']!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setS(() => participantId = v),
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
                  await api.createEvent(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    start: start,
                    end: end,
                    departmentIds: departmentId != null
                        ? [departmentId!]
                        : null,
                    participantIds: participantId != null
                        ? [participantId!]
                        : null,
                    type: 'work',
                  );
                  await api.fetchEvents();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Tạo'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _fmtDT(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _FabMenu extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onProjects;
  final VoidCallback onAddWorkEvent;
  const _FabMenu({
    required this.onAddTask,
    required this.onProjects,
    required this.onAddWorkEvent,
  });
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _AddSheet(
            onAddTask: onAddTask,
            onProjects: onProjects,
            onAddWorkEvent: onAddWorkEvent,
          ),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}

class _AddSheet extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onProjects;
  final VoidCallback onAddWorkEvent;
  const _AddSheet({
    required this.onAddTask,
    required this.onProjects,
    required this.onAddWorkEvent,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: () {
              Navigator.pop(context);
              onAddTask();
            },
            leading: const Icon(Icons.task_alt),
            title: const Text('Tạo Nhiệm vụ'),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context);
              onProjects();
            },
            leading: const Icon(Icons.workspaces),
            title: const Text('Dự án'),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context);
              onAddWorkEvent();
            },
            leading: const Icon(Icons.event_note),
            title: const Text('Lịch công tác'),
          ),
        ],
      ),
    );
  }
}
