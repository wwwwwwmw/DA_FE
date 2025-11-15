import 'project.dart';
import 'label.dart';
import 'user.dart';
import 'task_assignment.dart';

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final DateTime? startTime;
  final DateTime? endTime;
  final String status; // todo | in_progress | completed
  final String priority; // low | normal | high | urgent
  final ProjectModel? project;
  final UserModel? createdBy;
  final List<LabelModel> labels;
  final String assignmentType; // open | direct
  final int capacity; // slots
  final String? departmentId;
  final List<TaskAssignmentModel> assignments;
  final int? weight; // trọng số người dùng nhập (nullable)
  final int effectiveWeight; // trọng số hiệu dụng sau phân bổ

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    required this.status,
    required this.priority,
    this.project,
    this.createdBy,
    this.labels = const [],
    this.assignmentType = 'open',
    this.capacity = 1,
    this.departmentId,
    this.assignments = const [],
    this.weight,
    this.effectiveWeight = 0,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final labelsRaw = json['Labels'] ?? json['labels'] ?? [];
    final assignsRaw = json['assignments'] ?? json['Assignments'] ?? [];
    return TaskModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      status: json['status'] ?? 'todo',
      priority: json['priority'] ?? 'normal',
      project: (json['Project'] != null) ? ProjectModel.fromJson(json['Project']) : null,
      createdBy: (json['createdBy'] != null) ? UserModel.fromJson(json['createdBy']) : null,
      labels: (labelsRaw is List) ? labelsRaw.map((e) => LabelModel.fromJson(e as Map<String,dynamic>)).toList() : [],
      assignmentType: json['assignment_type'] ?? json['assignmentType'] ?? 'open',
      capacity: (json['capacity'] ?? 1) as int,
      departmentId: json['departmentId'] ?? json['department_id'],
      assignments: (assignsRaw is List)
          ? assignsRaw.map((e) => TaskAssignmentModel.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      weight: json['weight'] is int ? json['weight'] : (json['weight'] is num ? (json['weight'] as num).toInt() : null),
      effectiveWeight: json['effectiveWeight'] is int ? json['effectiveWeight'] : (json['effectiveWeight'] is num ? (json['effectiveWeight'] as num).toInt() : 0),
    );
  }
}
