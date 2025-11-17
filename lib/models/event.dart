import 'participant.dart';

class EventModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final List<ParticipantModel> participants;
  final String? departmentId;
  final bool isGlobal;

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.participants = const [],
    this.departmentId,
    this.isGlobal = false,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] ?? json['Participants'] ?? [];
    final parts = (rawParticipants is List)
        ? rawParticipants.map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>)).toList()
        : <ParticipantModel>[];
    return EventModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      startTime: DateTime.parse(json['start_time'] ?? json['startTime']),
      endTime: DateTime.parse(json['end_time'] ?? json['endTime']),
      status: json['status'] ?? 'pending',
      participants: parts,
      departmentId: json['departmentId'],
      isGlobal: (json['is_global'] ?? json['isGlobal'] ?? false) == true,
    );
  }
}
