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
  final String type; // work | meeting
  final List<String> extraDepartmentIds;
  final String? roomId;
  final String? roomName;
  final String? roomLocation;

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
    required this.type,
    this.extraDepartmentIds = const [],
    this.roomId,
    this.roomName,
    this.roomLocation,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] ?? json['Participants'] ?? [];
    final parts = (rawParticipants is List)
        ? rawParticipants
              .map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
              .toList()
        : <ParticipantModel>[];
    final extrasRaw = json['extraDepartments'] ?? [];
    final extraIds = (extrasRaw is List)
        ? extrasRaw
              .map(
                (e) => (e is Map && e['id'] != null)
                    ? e['id'].toString()
                    : e.toString(),
              )
              .toList()
        : <String>[];
    return EventModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      startTime: DateTime.parse(
        json['start_time'] ?? json['startTime'],
      ).toLocal(),
      endTime: DateTime.parse(json['end_time'] ?? json['endTime']).toLocal(),
      status: json['status'] ?? 'pending',
      participants: parts,
      departmentId: json['departmentId'],
      isGlobal: (json['is_global'] ?? json['isGlobal'] ?? false) == true,
      type: json['type'] ?? 'work',
      extraDepartmentIds: extraIds,
      roomId: json['roomId'],
      roomName: (json['Room']?['name']) ?? (json['room']?['name']),
      roomLocation: (json['Room']?['location']) ?? (json['room']?['location']),
    );
  }
}
