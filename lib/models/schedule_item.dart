class ScheduleItemModel {
  final String id;
  final String title;
  final String type; // 'task' | 'event'
  final DateTime? startTime;
  final DateTime? endTime;
  final String? status;
  final bool? isGlobal;
  final String? departmentId;
  final List<Map<String, dynamic>>
  participants; // events or task assignments simplified
  final String? priority; // tasks

  ScheduleItemModel({
    required this.id,
    required this.title,
    required this.type,
    this.startTime,
    this.endTime,
    this.status,
    this.isGlobal,
    this.departmentId,
    this.participants = const [],
    this.priority,
  });

  factory ScheduleItemModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDT(v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }

    return ScheduleItemModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'task',
      startTime: parseDT(json['start_time']),
      endTime: parseDT(json['end_time']),
      status: json['status'],
      isGlobal: json['is_global'],
      departmentId: json['departmentId']?.toString(),
      participants: (json['participants'] is List)
          ? (json['participants'] as List)
                .map<Map<String, dynamic>>(
                  (e) => (e is Map)
                      ? e.map((k, v) => MapEntry(k.toString(), v))
                      : <String, dynamic>{},
                )
                .toList()
          : const <Map<String, dynamic>>[],
      priority: json['priority'],
    );
  }
}
