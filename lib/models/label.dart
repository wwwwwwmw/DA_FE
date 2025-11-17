class LabelModel {
  final String id;
  final String name;
  final String color;

  const LabelModel({required this.id, required this.name, required this.color});

  factory LabelModel.fromJson(Map<String, dynamic> json) {
    return LabelModel(
      id: json['id'],
      name: json['name'] ?? '',
      color: json['color'] ?? '#2D9CDB',
    );
  }
}
