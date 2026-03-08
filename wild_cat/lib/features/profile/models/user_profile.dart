class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.birthday,
    required this.designation,
    required this.dateJoined,
  });

  final int id;
  final String username;
  final String email;
  final String fullName;
  final String? birthday;
  final String designation;
  final DateTime dateJoined;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      birthday: json['birthday'] as String?,
      designation: json['designation'] as String? ?? '',
      dateJoined: DateTime.parse(json['date_joined'] as String),
    );
  }
}
