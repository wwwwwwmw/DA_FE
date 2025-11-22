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
      if (mounted)
        setState(() {
          _comments = list;
          _loadingComments = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingComments = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final currentUser = api.currentUser;
    final task = widget.task;
    final assignments = task.assignments;
    String computedStatus;
    if (assignments.isNotEmpty && assignments.every((a) => a.progress >= 100)) {
      computedStatus = 'completed';
    } else if (assignments.any((a) => a.progress > 0 && a.progress < 100)) {
      computedStatus = 'in_progress';
    } else {
      computedStatus = 'todo';
    }
    final acceptedCount = assignments
        .where((a) => a.status == 'accepted' || a.status == 'completed')
        .length;
    // Removed isFull (UI no longer displays capacity status tag)
    final myAsg = currentUser == null
        ? null
        : assignments
              .where((a) => a.userId == currentUser.id)
              .cast<TaskAssignmentModel?>()
              .firstWhere((_) => true, orElse: () => null);

    final canManage =
        currentUser != null &&
        (currentUser.role == 'admin' ||
            (currentUser.role == 'manager' &&
                (task.departmentId == null ||
                    task.departmentId == currentUser.departmentId)) ||
            (task.createdBy?.id == currentUser.id));
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(task.title)),
            if (computedStatus == 'completed')
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
        actions: [
          if (canManage)
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    );
                  },
                );
                if (ok == true) {
                  await context.read<ApiService>().deleteTask(task.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status chips like mock
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('To Do'),
                    labelStyle: const TextStyle(color: Colors.black87),
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Colors.orangeAccent.withOpacity(0.2),
                    selected: computedStatus == 'todo',
                  ),
                  ChoiceChip(
                    label: const Text('In Progress'),
                    labelStyle: const TextStyle(color: Colors.black87),
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Colors.lightBlueAccent.withOpacity(0.2),
                    selected: computedStatus == 'in_progress',
                  ),
                  ChoiceChip(
                    label: const Text('Done'),
                    labelStyle: const TextStyle(color: Colors.black87),
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Colors.greenAccent.withOpacity(0.25),
                    selected: computedStatus == 'completed',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Properties card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _PropRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Due Date',
                        value: task.endTime != null ? _fmt(task.endTime!) : '-',
                      ),
                      const Divider(height: 24),
                      _PropRow(
                        icon: Icons.people_outline,
                        label: 'Assignees',
                        value: '${assignments.length}/${task.capacity}',
                      ),
                      const Divider(height: 24),
                      _PropRow(
                        icon: Icons.flag_outlined,
                        label: 'Priority',
                        value: task.priority,
                      ),
                      const Divider(height: 24),
                      _PropRow(
                        icon: Icons.folder_open,
                        label: 'Project',
                        value: task.project?.name ?? '-',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                task.description?.trim().isNotEmpty == true
                    ? task.description!.trim()
                    : '—',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (computedStatus == 'completed')
                      ? null
                      : () async {
                          final api = context.read<ApiService>();
                          try {
                            if (currentUser != null &&
                                currentUser.role == 'employee') {
                              // Employee marks own progress 100%
                              await api.updateTaskProgress(task.id, 100);
                            } else {
                              // Manager/Admin mark task status completed
                              await api.updateTask(
                                task.id,
                                status: 'completed',
                              );
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã cập nhật trạng thái hoàn thành',
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cập nhật thất bại'),
                              ),
                            );
                          }
                        },
                  child: Text(
                    computedStatus == 'completed'
                        ? 'Completed'
                        : 'Mark as Complete',
                  ),
                ),
              ),

              if (currentUser != null && currentUser.role == 'employee') ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Nhân viên không cần chấp nhận; có thể yêu cầu thay đổi.
                        if (myAsg != null &&
                            (myAsg.status == 'assigned' ||
                                myAsg.status == 'accepted') &&
                            myAsg.status != 'completed')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final reason = await _askRejectReason(context);
                              if (reason != null && reason.trim().isNotEmpty) {
                                await context.read<ApiService>().rejectTask(
                                  task.id,
                                  reason.trim(),
                                );
                                if (!mounted) return;
                                Navigator.pop(context);
                              }
                            },
                            icon: Icon(
                              Icons.block,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            label: const Text('Yêu cầu thay đổi'),
                          ),
                        if (myAsg != null) ...[
                          const SizedBox(height: 12),
                          Text('Tiến độ của bạn: ${(myAsg.progress)}%'),
                          Slider(
                            min: 0,
                            max: 100,
                            divisions: 20,
                            value: (_progressDraft ?? myAsg.progress.toDouble())
                                .clamp(0, 100),
                            onChanged:
                                (task.status == 'completed' ||
                                    myAsg.status == 'completed')
                                ? null
                                : (v) => setState(() {
                                    _progressDraft = v;
                                  }),
                            label:
                                '${(_progressDraft ?? myAsg.progress).round()}%',
                          ),
                          ElevatedButton.icon(
                            onPressed:
                                (task.status == 'completed' ||
                                    myAsg.status == 'completed')
                                ? null
                                : () async {
                                    final value =
                                        (_progressDraft ??
                                                myAsg.progress.toDouble())
                                            .round();
                                    await context
                                        .read<ApiService>()
                                        .updateTaskProgress(task.id, value);
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                  },
                            icon: const Icon(Icons.save),
                            label: const Text('Cập nhật tiến độ'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              if (currentUser != null &&
                  (currentUser.role == 'manager' ||
                      currentUser.role == 'admin')) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Phân công',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (assignments.isEmpty)
                          const Text('Chưa có phân công'),
                        ...assignments.map(
                          (a) => ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(a.user?.name ?? a.userId),
                            subtitle: Text('${a.status} • ${a.progress}%'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final selected = await _pickUser(context);
                            if (selected != null) {
                              final api = context.read<ApiService>();
                              // Ensure we have latest events
                              try {
                                await api.fetchEvents();
                              } catch (_) {}
                              final now = DateTime.now();
                              final conflict = api.events
                                  .where(
                                    (e) =>
                                        e.type == 'work' &&
                                        !now.isBefore(e.startTime) &&
                                        !now.isAfter(e.endTime) &&
                                        e.participants.any(
                                          (p) => p.userId == selected,
                                        ),
                                  )
                                  .toList();
                              if (conflict.isNotEmpty) {
                                final until = conflict.first.endTime;
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Nhân viên đang đi công tác tới ${_fmt(until)}; không thể giao việc.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              await api.assignTask(task.id, selected);
                              if (!mounted) return;
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Giao cho người dùng'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddTaskPage(editing: task),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Sửa công việc'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bình luận',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_loadingComments)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                      if (!_loadingComments && _comments.isEmpty)
                        const Text('Chưa có bình luận'),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                      setState(() {
                        _comments.add(cm);
                        _commentCtrl.clear();
                      });
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gửi bình luận thất bại')),
                      );
                    }
                  },
                  child: const Text('Gửi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _askRejectReason(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Yêu cầu thay đổi'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Mô tả yêu cầu thay đổi...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _pickUser(BuildContext context) async {
    final api = context.read<ApiService>();
    final users = await api.listUsers(limit: 100);
    // If manager, filter to own department users
    final me = api.currentUser;
    final filtered =
        (me != null && me.role == 'manager' && me.departmentId != null)
        ? users.where((u) => u.departmentId == me.departmentId).toList()
        : users;
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Assign to user'),
          children: [
            ...filtered.map(
              (u) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, u.id),
                child: Text(u.name),
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PropRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PropRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.black),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

// Placeholder subtask & attachment widgets removed after reconnecting real data logic.
