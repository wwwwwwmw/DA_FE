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

  UserModel({
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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'employee',
      departmentId: json['departmentId'],
      contact: json['contact'],
      employeePin: json['employee_pin'] ?? json['employeePin'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      isLocked: json['is_locked'] ?? false,
      failedLoginAttempts: json['failed_login_attempts'] ?? 0,
    );
  }

  UserModel copyWith({
    String? name,
    String? contact,
    String? employeePin,
    String? avatarUrl,
  }) => UserModel(
    id: id,
    name: name ?? this.name,
    email: email,
    role: role,
    departmentId: departmentId,
    contact: contact ?? this.contact,
    employeePin: employeePin ?? this.employeePin,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isLocked: isLocked,
    failedLoginAttempts: failedLoginAttempts,
  );
}
