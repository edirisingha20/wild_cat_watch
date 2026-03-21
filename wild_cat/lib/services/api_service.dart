import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class ApiService {
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final bool isPublic = _publicPaths.any(
            (String path) => options.path.contains(path),
          );

          if (!isPublic) {
            final String? token = await StorageService().getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  late final Dio _dio;

  Dio get dio => _dio;

  static final String _baseUrl = kIsWeb
      ? 'http://localhost:8000/api/'
      : 'http://10.0.2.2:8000/api/';

  static const List<String> _publicPaths = <String>[
    'auth/login/',
    'auth/register/',
    'sightings/',
    'sightings/nearby/',
  ];
}
