import 'dart:io';

import 'package:dio/dio.dart';

import '../features/sightings/models/alert_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class SightingsService {
  final ApiService _api = ApiService();
  final StorageService _storageService = StorageService();

  Future<List<Alert>> fetchSightings() async {
    final response = await _api.dio.get('sightings/');
    final List<dynamic> data = response.data as List<dynamic>;

    return data
        .map(
          (dynamic json) =>
              Alert.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<List<Alert>> fetchNearbySightings({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _api.dio.get(
      'sightings/nearby/',
      queryParameters: <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
      },
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map(
          (dynamic json) =>
              Alert.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<void> reportSighting({
    required String description,
    required double latitude,
    required double longitude,
    required String locationName,
    required File imageFile,
  }) async {
    final String? token = await _storageService.getToken();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: 'sightings/report/'),
        error: 'Authentication token not found. Please login again.',
      );
    }

    final FormData formData = FormData.fromMap(<String, dynamic>{
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'image': await MultipartFile.fromFile(imageFile.path),
    });

    await _api.dio.post(
      'sightings/report/',
      data: formData,
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }
}
