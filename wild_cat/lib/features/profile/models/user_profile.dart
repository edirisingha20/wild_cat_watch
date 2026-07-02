import 'lookup_option.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.birthday,
    required this.department,
    required this.position,
  });

  final int id;
  final String username;
  final String email;
  final String fullName;
  final String? birthday;
  final LookupOption? department;
  final LookupOption? position;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      birthday: json['birthday'] as String?,
      department: json['department'] is Map<String, dynamic>
          ? LookupOption.fromJson(Map<String, dynamic>.from(json['department'] as Map))
          : null,
      position: json['position'] is Map<String, dynamic>
          ? LookupOption.fromJson(Map<String, dynamic>.from(json['position'] as Map))
          : null,
    );
  }
}
