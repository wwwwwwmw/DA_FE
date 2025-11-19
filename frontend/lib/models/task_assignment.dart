import 'user.dart';

class TaskAssignmentModel {
  final String id;
  final String taskId;
  final String userId;
  final String status; // applied | assigned | accepted | rejected | completed
  final int progress; // 0-100
  final UserModel? user;

  TaskAssignmentModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.status,
    required this.progress,
    this.user,
  });

  factory TaskAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TaskAssignmentModel(
      id: json['id'],
      taskId: json['taskId'] ?? json['task_id'],
      userId: json['userId'] ?? json['user_id'],
      status: json['status'] ?? 'applied',
      progress: (json['progress'] ?? 0) as int,
      user: json['User'] != null ? UserModel.fromJson(json['User']) : null,
    );
  }
}
