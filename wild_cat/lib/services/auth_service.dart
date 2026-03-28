import 'package:dio/dio.dart';

import 'api_service.dart';

class AuthService {
  AuthService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final Response<dynamic> response = await _apiService.post(
      'auth/login/',
      data: <String, dynamic>{
        'identifier': identifier,
        'password': password,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Response<dynamic>> register(Map<String, dynamic> data) {
    return _apiService.post(
      'auth/register/',
      data: data,
    );
  }
}
