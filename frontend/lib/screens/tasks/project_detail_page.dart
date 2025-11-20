// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';
import 'add_task_page.dart';
import 'task_detail_page.dart';
import '../../widgets/task_list_item_card.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  const ProjectDetailPage({super.key, required this.projectId, required this.projectName});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  List<TaskModel> _tasks = const [];
  bool _loading = true;
  int _explicitSum = 0; // tổng trọng số do người dùng nhập
  int _effectiveTotal = 0; // tổng trọng số hiệu dụng (nên =100 hoặc = explicitSum nếu <100)
  int _todoCount = 0;
  int _inProgressCount = 0;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final list = await api.listTasksForProject(widget.projectId);
    // Tính toán trọng số
    int explicit = 0;
    for (final t in list) {
      if (t.weight != null) explicit += t.weight!;
    }
    int effTotal = 0;
    for (final t in list) { effTotal += t.effectiveWeight; }
    // Đếm theo trạng thái cho riêng project này (list chỉ chứa task của project này)
    int todo = 0, doing = 0, done = 0;
    for (final t in list) {
      if (t.status == 'completed') {
        done++;
      } else if (t.status == 'in_progress') {
        doing++;
      } else {
        // treat others as todo (e.g., 'todo')
        todo++;
      }
    }
    if (!mounted) return;
    setState(() { _tasks = list; _loading = false; _explicitSum = explicit; _effectiveTotal = effTotal; _todoCount = todo; _inProgressCount = doing; _completedCount = done; });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<ApiService>().currentUser;
    final canManage = me != null && (me.role == 'admin' || me.role == 'manager');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final edited = await _openEditProject(context);
                if (!mounted) return;
                if (edited == true) await _load();
              },
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Xóa project'),
                    content: const Text('Bạn có chắc muốn xóa project này?'),
                    actions: [
                      TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: const Text('Hủy')),
                      ElevatedButton(onPressed: ()=> Navigator.pop(ctx,true), child: const Text('Xóa')),
                    ],
                  );
                });
                if (ok == true) {
                  if (!context.mounted) return;
                  await context.read<ApiService>().deleteProject(widget.projectId);
                  if (!mounted) return;
                  Navigator.pop(context);
                }
              },
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('Chưa có task trong project này'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: const [
                            Icon(Icons.bar_chart, size: 18),
                            SizedBox(width: 6),
                            Text('Tổng quan trọng số', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height:8),
                          Text('Tổng trọng số nhập: $_explicitSum%'),
                          Text('Tổng trọng số hiệu dụng: $_effectiveTotal%'),
                          if (_explicitSum > 100)
                            const Padding(
                              padding: EdgeInsets.only(top:4.0),
                              child: Text('Cảnh báo: Tổng trọng số đã vượt 100%', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height:12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Trạng thái nhiệm vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 220,
                            child: PieChart(
                              PieChartData(
                                sections: _buildStatusSections(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _legendRow('Completed', _completedCount, Colors.green),
                          _legendRow('In Progress', _inProgressCount, Colors.blue),
                          _legendRow('To Do', _todoCount, Colors.orange),
                        ]),
                      ),
                    ),
                    const SizedBox(height:12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: DataTable(columns: const [
                        DataColumn(label: Text('Task')),
                        DataColumn(label: Text('Nhập')),
                        DataColumn(label: Text('Hiệu dụng')),
                        DataColumn(label: Text('Tiến độ')),
                      ], rows: _tasks.map((t) {
                        double progress;
                        if (t.assignments.isEmpty) {
                          progress = t.status == 'completed' ? 1.0 : 0.0;
                        } else {
                          final rel = t.assignments.where((a) => a.status != 'rejected').toList();
                          if (rel.isEmpty) {
                            progress = 0.0;
                          } else {
                            final sum = rel.fold<int>(0, (a,b)=> a + b.progress);
                            progress = sum / (rel.length * 100.0);
                          }
                        }
                        return DataRow(cells: [
                          DataCell(Text(t.title, maxLines:1, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(t.weight?.toString() ?? '-')),
                          DataCell(Text('${t.effectiveWeight}%')),
                          DataCell(Text('${(progress*100).round()}%')),
                        ]);
                      }).toList()),
                    ),
                    const SizedBox(height:16),
                    const Text('Danh sách nhiệm vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height:8),
                    ..._tasks.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TaskListItemCard(
                        task: t,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(task: t)));
                          if (!mounted) return;
                          await _load();
                        },
                      ),
                    ))
                  ],
                ),
      floatingActionButton: (me != null && me.role != 'employee')
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AddTaskPage(preselectedProjectId: widget.projectId)));
                if (!mounted) return;
                await _load();
              },
              child: const Icon(Icons.add_task),
            )
          : null,
    );
  }

  Future<bool?> _openEditProject(BuildContext context) async {
    final api = context.read<ApiService>();
    final nameCtrl = TextEditingController(text: widget.projectName);
    final descCtrl = TextEditingController();
    return showDialog<bool>(context: context, builder: (ctx){
      return AlertDialog(
        title: const Text('Sửa project'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên')),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines: 3),
        ]),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            await api.updateProject(widget.projectId, name: nameCtrl.text.trim(), description: descCtrl.text.trim().isEmpty? null : descCtrl.text.trim());
            if (ctx.mounted) Navigator.pop(ctx,true);
          }, child: const Text('Lưu')),
        ],
      );
    });
  }

  List<PieChartSectionData> _buildStatusSections() {
    final total = _todoCount + _inProgressCount + _completedCount;
    return [
      _sec(_todoCount, total, Colors.orange, 'To Do'),
      _sec(_inProgressCount, total, Colors.blue, 'In Progress'),
      _sec(_completedCount, total, Colors.green, 'Completed'),
    ];
  }

  PieChartSectionData _sec(int value, int total, Color color, String label) {
    final pct = total == 0 ? 0 : (value / total) * 100;
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: '${pct.round()}%',
      radius: 60,
      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Row(children: [
      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('$label: $value')
    ]);
  }
}
