class AuthUser {
  const AuthUser({
    required this.fullName,
    required this.username,
    required this.email,
    required this.designation,
  });

  final String fullName;
  final String username;
  final String email;
  final String designation;
}
