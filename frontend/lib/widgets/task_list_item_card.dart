import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskListItemCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  const TaskListItemCard({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'completed';
    final projectName = task.project?.name ?? 'Không có dự án';
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: isDone,
                onChanged: null, // read-only indicator
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => isDone ? Colors.green : Colors.transparent,
                ),
                checkColor: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      projectName,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isDone) ...[
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
              ],
              _statusChip(task.status, cs),
              const SizedBox(width: 8),
              _priorityChip(task.priority, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityChip(String priority, ColorScheme cs) {
    String label;
    Color color;
    switch (priority) {
      case 'high':
        label = 'Cao';
        color = cs.error;
        break;
      case 'urgent':
        label = 'Khẩn cấp';
        color = cs.error;
        break;
      case 'low':
        label = 'Thấp';
        color = cs.secondary;
        break;
      default:
        label = 'B.Thường';
        color = cs.primary;
    }
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _statusChip(String status, ColorScheme cs) {
    String label;
    Color color;
    switch (status) {
      case 'completed':
        label = 'Hoàn thành';
        color = Colors.green;
        break;
      case 'in_progress':
        label = 'Đang làm';
        color = Colors.blue;
        break;
      default:
        label = 'Cần làm';
        color = Colors.orange;
    }
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: const TextStyle(color: Colors.black87),
    );
  }
}
