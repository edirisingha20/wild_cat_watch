import 'api_service.dart';

class LocationApiService {
  final ApiService _api = ApiService();

  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _api.post(
      'users/location/',
      data: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }
}
