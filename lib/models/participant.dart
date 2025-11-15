import 'user.dart';

class ParticipantModel {
  final String id;
  final String eventId;
  final String userId;
  final String status; // pending | accepted | declined
  final UserModel? user; // optional embedded user from include

  const ParticipantModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    this.user,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'],
      eventId: json['eventId'] ?? json['event_id'],
      userId: json['userId'] ?? json['user_id'],
      status: json['status'] ?? 'pending',
      user: json['User'] != null || json['user'] != null
          ? UserModel.fromJson((json['User'] ?? json['user']) as Map<String, dynamic>)
          : null,
    );
  }
}
