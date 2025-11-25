import '../../domain/entities/user.dart';

/// User model for data layer - handles JSON serialization/deserialization
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? departmentId;
  final String? contact;
  final String? employeePin;
  final String? avatarUrl;
  final bool isLocked;
  final int failedLoginAttempts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.departmentId,
    this.contact,
    this.employeePin,
    this.avatarUrl,
    this.isLocked = false,
    this.failedLoginAttempts = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'employee',
      departmentId: json['departmentId'] as String?,
      contact: json['contact'] as String?,
      employeePin:
          json['employee_pin'] as String? ?? json['employeePin'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      isLocked: json['is_locked'] as bool? ?? false,
      failedLoginAttempts: json['failed_login_attempts'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'departmentId': departmentId,
      'contact': contact,
      'employeePin': employeePin,
      'avatarUrl': avatarUrl,
      'isLocked': isLocked,
      'failedLoginAttempts': failedLoginAttempts,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  User toEntity() {
    return User(
      id: id,
      name: name,
      email: email,
      role: role,
      departmentId: departmentId,
      contact: contact,
      employeePin: employeePin,
      avatarUrl: avatarUrl,
      isLocked: isLocked,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create UserModel from domain entity
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      departmentId: user.departmentId,
      contact: user.contact,
      employeePin: user.employeePin,
      avatarUrl: user.avatarUrl,
      isLocked: user.isLocked,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel{id: $id, name: $name, email: $email, role: $role}';
  }
}
