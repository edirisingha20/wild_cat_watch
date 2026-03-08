import 'package:dio/dio.dart';

import '../features/profile/models/user_profile.dart';
import 'api_service.dart';
import 'storage_service.dart';

class ProfileService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Future<UserProfile> getProfile() async {
    final String token = await _getRequiredToken();

    final Response<dynamic> response = await _apiService.dio.get(
      'users/me/',
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return UserProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    required String? birthday,
    required String designation,
  }) async {
    final String token = await _getRequiredToken();

    final Response<dynamic> response = await _apiService.dio.patch(
      'users/me/',
      data: <String, dynamic>{
        'full_name': fullName,
        'birthday': birthday,
        'designation': designation,
      },
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return UserProfile.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<String> _getRequiredToken() async {
    final String? token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: 'users/me/'),
        error: 'Authentication token not found',
      );
    }
    return token;
  }
}
