/// User domain entity
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? departmentId;
  final String? contact;
  final String? employeePin;
  final String? avatarUrl;
  final bool isLocked;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.departmentId,
    this.contact,
    this.employeePin,
    this.avatarUrl,
    this.isLocked = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Business logic methods
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isEmployee => role == 'employee';

  bool canManageUser(User targetUser) {
    if (isAdmin) return true;
    if (isManager && targetUser.departmentId == departmentId) return true;
    return id == targetUser.id; // Self management
  }

  bool canCreateUser() {
    return isAdmin || isManager;
  }

  bool canDeleteUser() {
    return isAdmin;
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? departmentId,
    String? contact,
    String? employeePin,
    String? avatarUrl,
    bool? isLocked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      departmentId: departmentId ?? this.departmentId,
      contact: contact ?? this.contact,
      employeePin: employeePin ?? this.employeePin,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User{id: $id, name: $name, email: $email, role: $role}';
  }
}
