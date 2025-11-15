class NotificationModel {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? refType; // 'event' | 'task' | ...
  final String? refId;

  NotificationModel({required this.id, required this.title, required this.message, required this.isRead, required this.createdAt, this.refType, this.refId});

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: (json['is_read'] ?? false) as bool,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      refType: json['ref_type'] ?? json['refType'],
      refId: json['ref_id'] ?? json['refId'],
    );
  }
}
