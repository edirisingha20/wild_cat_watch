import 'package:dio/dio.dart';

import '../features/profile/models/user_profile.dart';
import 'api_service.dart';

class ProfileService {
  final ApiService _apiService = ApiService();

  Future<UserProfile> getProfile() async {
    final Response<dynamic> response = await _apiService.get('users/me/');
    return UserProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    required String? birthday,
    required String designation,
  }) async {
    final Response<dynamic> response = await _apiService.patch(
      'users/me/',
      data: <String, dynamic>{
        'full_name': fullName,
        'birthday': birthday,
        'designation': designation,
      },
    );

    return UserProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
