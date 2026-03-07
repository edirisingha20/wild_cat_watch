import 'package:dio/dio.dart';

import 'api_service.dart';
import 'storage_service.dart';

class LocationApiService {
  final ApiService _api = ApiService();
  final StorageService _storageService = StorageService();

  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
  }) async {
    final String? token = await _storageService.getToken();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: 'users/location/'),
        error: 'Authentication token not found. Please login again.',
      );
    }

    await _api.dio.post(
      'users/location/',
      data: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      },
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
}
