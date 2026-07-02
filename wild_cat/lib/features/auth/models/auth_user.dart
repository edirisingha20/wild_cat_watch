class AuthUser {
  const AuthUser({
    required this.fullName,
    required this.username,
    required this.email,
    required this.departmentName,
    required this.positionName,
  });

  final String fullName;
  final String username;
  final String email;
  final String departmentName;
  final String positionName;
}
