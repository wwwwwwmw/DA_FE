class ProjectModel {
  final String id;
  final String name;
  final String? description;
  final int? progress; // percentage computed server side

  ProjectModel({required this.id, required this.name, this.description, this.progress});

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      progress: json['progress'] is num ? (json['progress'] as num).toInt() : null,
    );
  }
}
