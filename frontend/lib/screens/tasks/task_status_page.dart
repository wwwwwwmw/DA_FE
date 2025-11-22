import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';
import '../../widgets/task_list_item_card.dart';

class TaskStatusPage extends StatefulWidget {
  const TaskStatusPage({super.key});
  @override
  State<TaskStatusPage> createState() => _TaskStatusPageState();
}

class _TaskStatusPageState extends State<TaskStatusPage> {
  String? _selectedStatus; // 'todo' | 'in_progress' | 'completed'
  String? _projectId; // filter by project
  DateTimeRange? _range; // filter by date range

  @override
  void initState() {
    super.initState();
    // Ensure tasks are loaded for list below
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = context.read<ApiService>();
      await api.fetchTasks();
      await api.fetchProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final projects = api.projects;
    final filtered = _filteredTasks(api.tasks);
    final stats = _computeStats(filtered);
    // Nếu đang lọc theo trạng thái mà không còn task nào, tự bỏ lọc trạng thái
    if (_selectedStatus != null && stats[_selectedStatus] == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedStatus = null);
      });
    }
    final total = stats['todo']! + stats['in_progress']! + stats['completed']!;
    final allZero = total == 0;
    final sections = allZero
        ? [
            PieChartSectionData(
              value: 1,
              color: Colors.grey.shade300,
              title: '0',
              radius: 60,
              titleStyle: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]
        : [
            _sec(stats['todo']!, total, Colors.orange, 'Cần làm'),
            _sec(stats['in_progress']!, total, Colors.blue, 'Đang làm'),
            _sec(stats['completed']!, total, Colors.green, 'Hoàn thành'),
          ];
    return Scaffold(
      appBar: AppBar(title: const Text('Trạng thái Nhiệm vụ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _projectId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Dự án',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tất cả dự án'),
                      ),
                      ...projects.map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _projectId = v;
                      _selectedStatus = null; // đổi dự án thì bỏ lọc trạng thái
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 5),
                          initialDateRange: _range,
                        );
                        if (picked != null) {
                          setState(() {
                            _range = picked;
                            _selectedStatus =
                                null; // đổi khoảng ngày thì bỏ lọc trạng thái
                          });
                        }
                      },
                      icon: const Icon(Icons.filter_alt),
                      label: Text(
                        _range == null
                            ? 'Khoảng ngày'
                            : '${_fmtDate(_range!.start)} → ${_fmtDate(_range!.end)}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() {
                    _projectId = null;
                    _range = null;
                    _selectedStatus = null;
                  }),
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  // Chỉ hiển thị biểu đồ, không có tương tác chuột/touch
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _legendRow('Hoàn thành', stats['completed']!, Colors.green),
            _legendRow('Đang làm', stats['in_progress']!, Colors.blue),
            _legendRow('Cần làm', stats['todo']!, Colors.orange),
            const SizedBox(height: 16),
            if (_selectedStatus != null)
              Text(
                'Lọc trạng thái: ${_localized(_selectedStatus!)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TaskListItemCard(task: filtered[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _sec(int value, int total, Color color, String title) {
    final pct = total == 0 ? 0 : (value / total) * 100;
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: '${pct.round()}%',
      radius: 60,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label: $value'),
      ],
    );
  }

  List<TaskModel> _filteredTasks(List<TaskModel> tasks) {
    Iterable<TaskModel> list = tasks;
    if (_selectedStatus != null) {
      list = list.where((t) => _derivedStatus(t) == _selectedStatus);
    }
    if (_projectId != null) {
      list = list.where((t) => t.project?.id == _projectId);
    }
    if (_range != null) {
      final start = _range!.start;
      final end = _range!.end;
      bool overlaps(TaskModel t) {
        final s = t.startTime;
        final e = t.endTime ?? t.startTime;
        if (s == null && e == null) {
          return true;
        }
        final from = s ?? e!;
        final to = e ?? s!;
        return !(to.isBefore(start) || from.isAfter(end));
      }

      list = list.where(overlaps);
    }
    return list.toList();
  }

  Map<String, int> _computeStats(List<TaskModel> tasks) {
    int todo = 0, inProgress = 0, completed = 0;
    for (final t in tasks) {
      final s = _derivedStatus(t);
      if (s == 'completed')
        completed++;
      else if (s == 'in_progress')
        inProgress++;
      else
        todo++;
    }
    return {'todo': todo, 'in_progress': inProgress, 'completed': completed};
  }

  String _derivedStatus(TaskModel t) {
    final asg = t.assignments;
    if (asg.isNotEmpty && asg.every((a) => a.progress >= 100))
      return 'completed';
    if (asg.any((a) => a.progress > 0 && a.progress < 100))
      return 'in_progress';
    return 'todo';
  }

  String _localized(String status) {
    switch (status) {
      case 'completed':
        return 'Hoàn thành';
      case 'in_progress':
        return 'Đang làm';
      default:
        return 'Cần làm';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
