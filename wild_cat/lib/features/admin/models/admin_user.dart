class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.departmentName,
    this.positionName,
  });

  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
  final String? departmentName;
  final String? positionName;

  bool get isAdmin => role == 'admin';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
      departmentName: json['department'] is Map
          ? (json['department'] as Map)['name'] as String?
          : null,
      positionName: json['position'] is Map
          ? (json['position'] as Map)['name'] as String?
          : null,
    );
  }
}
