// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/task_assignment.dart';
import '../../models/task_comment.dart';
import '../../services/api_service.dart';
import 'add_task_page.dart';

class TaskDetailPage extends StatefulWidget {
  final TaskModel task;
  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  double? _progressDraft;
  List<TaskCommentModel> _comments = [];
  bool _loadingComments = true;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final api = context.read<ApiService>();
      final list = await api.fetchTaskComments(widget.task.id);
      if (mounted) setState(() { _comments = list; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingComments = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final currentUser = api.currentUser;
    final task = widget.task;
    final assignments = task.assignments;
  final acceptedCount = assignments.where((a) => a.status == 'accepted' || a.status == 'completed').length;
  final isFull = acceptedCount >= task.capacity;
    final myAsg = currentUser == null ? null : assignments.where((a) => a.userId == currentUser.id).cast<TaskAssignmentModel?>().firstWhere((_)=>true, orElse: ()=>null);

    final canManage = currentUser != null && (
      currentUser.role == 'admin' ||
      (currentUser.role == 'manager' && (task.departmentId == null || task.departmentId == currentUser.departmentId)) ||
      (task.createdBy?.id == currentUser.id)
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Công việc'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Xóa nhiệm vụ'),
                    content: const Text('Bạn có chắc muốn xóa nhiệm vụ này?'),
                    actions: [
                      TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: const Text('Hủy')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                        onPressed: ()=> Navigator.pop(ctx,true), child: const Text('Xóa')
                      ),
                    ],
                  );
                });
                if (ok == true) {
                  await context.read<ApiService>().deleteTask(task.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (task.description != null) Text(task.description!),
                  const SizedBox(height: 12),
                  Wrap(spacing:8, runSpacing: 8, children: [
                    Chip(label: Text(task.status.replaceAll('_',' '))),
                    Chip(label: Text('Độ ưu tiên: ${task.priority}')),
                    Chip(label: Text('Hình thức: ${task.assignmentType}')),
                    Chip(label: Text('Chỗ: $acceptedCount / ${task.capacity}')),
                    if (isFull) Chip(label: const Text('Đủ người'), backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.18)),
                  ]),
                  const SizedBox(height: 8),
                  if (task.startTime != null) Text('Bắt đầu: ${task.startTime}'),
                  if (task.endTime != null) Text('Kết thúc: ${task.endTime}'),
                ]),
              ),
            ),

            if (currentUser != null && currentUser.role == 'employee') ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (task.assignmentType == 'open' && myAsg == null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: (isFull || task.status == 'completed') ? null : () async {
                          await context.read<ApiService>().applyTask(task.id);
                          if (!mounted) return; 
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.how_to_reg),
                        label: const Text('Nhận nhiệm vụ này'),
                      ),
                    if (myAsg != null && myAsg.status == 'assigned') ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: (isFull || task.status == 'completed') ? null : () async {
                          await context.read<ApiService>().acceptTask(task.id);
                          if (!mounted) return; 
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Chấp nhận'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (myAsg != null && (myAsg.status == 'assigned' || myAsg.status == 'accepted') && myAsg.status != 'completed')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                        onPressed: () async {
                          final reason = await _askRejectReason(context);
                          if (reason != null && reason.trim().isNotEmpty) {
                            await context.read<ApiService>().rejectTask(task.id, reason.trim());
                            if (!mounted) return; 
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('Từ chối nhiệm vụ'),
                      ),
                    if (myAsg != null) ...[
                      const SizedBox(height: 12),
                      Text('Tiến độ của bạn: ${(myAsg.progress)}%'),
                      Slider(
                        min: 0,
                        max: 100,
                        divisions: 20,
                        value: (_progressDraft ?? myAsg.progress.toDouble()).clamp(0,100),
                        onChanged: (task.status == 'completed' || myAsg.status == 'completed') ? null : (v) => setState(() { _progressDraft = v; }),
                        label: '${(_progressDraft ?? myAsg.progress).round()}%',
                      ),
                      ElevatedButton.icon(
                        onPressed: (task.status == 'completed' || myAsg.status == 'completed') ? null : () async {
                          final value = (_progressDraft ?? myAsg.progress.toDouble()).round();
                          await context.read<ApiService>().updateTaskProgress(task.id, value);
                          if (!mounted) return; 
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Cập nhật tiến độ'),
                      )
                    ]
                  ]),
                ),
              ),
            ],

            const SizedBox(height: 12),
            if (currentUser != null && (currentUser.role == 'manager' || currentUser.role == 'admin'))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Phân công', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (assignments.isEmpty) const Text('Chưa có phân công'),
                    ...assignments.map((a) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(a.user?.name ?? a.userId),
                      subtitle: Text('${a.status} • ${a.progress}%'),
                    )),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final selected = await _pickUser(context);
                        if (selected != null) {
                          await context.read<ApiService>().assignTask(task.id, selected);
                          if (!mounted) return; 
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Giao cho người dùng'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => AddTaskPage(editing: task))); },
                      icon: const Icon(Icons.edit),
                      label: const Text('Sửa công việc'),
                    )
                  ]),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => AddTaskPage(editing: task))); },
                    icon: const Icon(Icons.edit),
                    label: const Text('Sửa'),
                  ),
                ),
              )
            ],

            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bình luận', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_loadingComments) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()),
                  if (!_loadingComments && _comments.isEmpty) const Text('Chưa có bình luận'),
                  if (!_loadingComments && _comments.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (ctx, i) {
                        final c = _comments[i];
                        return ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(c.user?.name ?? c.userId),
                          subtitle: Text(c.content),
                        );
                      },
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Viết bình luận...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = _commentCtrl.text.trim();
                    if (text.isEmpty) return;
                    try {
                      final api = context.read<ApiService>();
                      final cm = await api.addTaskComment(widget.task.id, text);
                      setState(() { _comments.add(cm); _commentCtrl.clear(); });
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gửi bình luận thất bại')));
                    }
                  },
                  child: const Text('Gửi'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _askRejectReason(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Lý do từ chối'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Nhập lý do...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Gửi')),
        ],
      );
    });
  }

  Future<String?> _pickUser(BuildContext context) async {
    final api = context.read<ApiService>();
    final users = await api.listUsers(limit: 100);
    // If manager, filter to own department users
    final me = api.currentUser;
    final filtered = (me != null && me.role == 'manager' && me.departmentId != null)
        ? users.where((u) => u.departmentId == me.departmentId).toList()
        : users;
    return showDialog<String>(context: context, builder: (ctx) {
      return SimpleDialog(title: const Text('Assign to user'), children: [
        ...filtered.map((u) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, u.id), child: Text(u.name)))
      ]);
    });
  }
}
