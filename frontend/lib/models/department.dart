class DepartmentModel {
  final String id;
  final String name;
  final String? description;

  DepartmentModel({required this.id, required this.name, this.description});

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
  };

  DepartmentModel copyWith({String? name, String? description}) => DepartmentModel(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
  );
}
