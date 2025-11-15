import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../services/api_service.dart';
import 'project_detail_page.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  @override
  void initState() {
    super.initState();
    context.read<ApiService>().fetchProjects();
  }
  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ApiService>().projects;
    return Scaffold(
      appBar: AppBar(title: const Text('Dự án')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: projects.length,
        itemBuilder: (_, i) {
          final p = projects[i];
          final pct = (p.progress ?? 0) / 100.0;
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailPage(projectId: p.id, projectName: p.name))),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (p.description != null) Text(p.description!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  LinearPercentIndicator(percent: pct.clamp(0,1), lineHeight: 8, progressColor: const Color(0xFF2D9CDB), backgroundColor: Colors.grey.shade200, barRadius: const Radius.circular(6)),
                  const SizedBox(height: 4),
                  Text('${p.progress ?? 0}% hoàn thành', style: const TextStyle(fontSize: 12, color: Colors.black54))
                ]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: (context.read<ApiService>().currentUser?.role == 'employee') ? null : FloatingActionButton(
        onPressed: () async {
          await _createProjectDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createProjectDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool createEvent = false;
    DateTime? start;
    DateTime? end;
    await showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Tạo Dự án'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Tạo lịch công tác'),
                value: createEvent,
                onChanged: (v) => setS(() => createEvent = v),
              ),
              if (createEvent) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: ctx, firstDate: DateTime(now.year-1), lastDate: DateTime(now.year+2), initialDate: now);
                    if (d == null) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                    if (t == null) return;
                    setS(() => start = DateTime(d.year,d.month,d.day,t.hour,t.minute));
                  },
                  child: Text(start==null? 'Chọn thời gian bắt đầu' : start.toString()),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: ctx, firstDate: DateTime(now.year-1), lastDate: DateTime(now.year+2), initialDate: now);
                    if (d == null) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                    if (t == null) return;
                    setS(() => end = DateTime(d.year,d.month,d.day,t.hour,t.minute));
                  },
                  child: Text(end==null? 'Chọn thời gian kết thúc' : end.toString()),
                ),
              ]
            ]),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final api = context.read<ApiService>();
              await api.createProject(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty? null : descCtrl.text.trim(),
                createEvent: createEvent,
                eventStart: start,
                eventEnd: end,
              );
              if (context.mounted) Navigator.pop(ctx);
            }, child: const Text('Tạo'))
          ],
        );
      });
    });
    setState(() {});
  }
}
