import 'dart:io';

import 'package:dio/dio.dart';

import '../features/sightings/models/alert_model.dart';
import 'api_service.dart';

class SightingsService {
  final ApiService _api = ApiService();

  /// Fetches the paginated sightings list.
  /// DRF returns `{count, next, previous, results}` when pagination is enabled.
  Future<List<Alert>> fetchSightings({int page = 1}) async {
    final response = await _api.dio.get(
      'sightings/',
      queryParameters: <String, dynamic>{'page': page},
    );

    final dynamic body = response.data;
    final List<dynamic> results = body is Map<String, dynamic>
        ? (body['results'] as List<dynamic>? ?? <dynamic>[])
        : body as List<dynamic>;

    return results
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

    // Nearby endpoint returns a plain list (no pagination).
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
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }
}
