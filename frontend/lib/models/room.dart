class RoomModel {
  final String id;
  final String name;
  final String? location;
  final int? capacity;

  RoomModel({
    required this.id,
    required this.name,
    this.location,
    this.capacity,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      location: json['location'],
      capacity: json['capacity'] == null
          ? null
          : int.tryParse(json['capacity'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (location != null) 'location': location,
    if (capacity != null) 'capacity': capacity,
  };

  RoomModel copyWith({String? name, String? location, int? capacity}) =>
      RoomModel(
        id: id,
        name: name ?? this.name,
        location: location ?? this.location,
        capacity: capacity ?? this.capacity,
      );
}
