import 'user.dart';

class TaskCommentModel {
  final String id;
  final String taskId;
  final String userId;
  final String content;
  final UserModel? user;

  TaskCommentModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    this.user,
  });

  factory TaskCommentModel.fromJson(Map<String, dynamic> json) {
    return TaskCommentModel(
      id: json['id'] as String,
      taskId: (json['taskId'] ?? json['task_id']) as String,
      userId: (json['userId'] ?? json['user_id']) as String,
      content: (json['content'] ?? '').toString(),
      user: (json['User'] != null || json['user'] != null)
          ? UserModel.fromJson((json['User'] ?? json['user']) as Map<String, dynamic>)
          : null,
    );
  }
}
