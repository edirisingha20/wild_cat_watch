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
    required int departmentId,
    required int positionId,
  }) async {
    final Response<dynamic> response = await _apiService.patch(
      'users/me/',
      data: <String, dynamic>{
        'full_name': fullName,
        'birthday': birthday,
        'department_id': departmentId,
        'position_id': positionId,
      },
    );

    return UserProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Updates only the preferred sighting radius (km).
  Future<UserProfile> updateRadius(double radiusKm) async {
    final Response<dynamic> response = await _apiService.patch(
      'users/me/',
      data: <String, dynamic>{'sighting_radius_km': radiusKm},
    );
    return UserProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
