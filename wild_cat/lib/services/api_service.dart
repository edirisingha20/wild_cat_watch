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
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401 &&
              !_isAuthPath(error.requestOptions.path)) {
            final bool refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request with the new token.
              final String? newToken = await StorageService().getToken();
              if (newToken != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              }
              try {
                final Response<dynamic> response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          handler.next(error);
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
    'token/refresh/',
  ];

  bool _isRefreshing = false;

  static bool _isAuthPath(String path) {
    return path.contains('auth/login/') ||
        path.contains('auth/register/') ||
        path.contains('token/refresh/');
  }

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) {
      return false;
    }
    _isRefreshing = true;
    try {
      final StorageService storage = StorageService();
      final String? refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final Response<dynamic> response = await Dio(
        BaseOptions(baseUrl: _baseUrl),
      ).post(
        'token/refresh/',
        data: <String, String>{'refresh': refreshToken},
      );

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(response.data as Map);
      final String? newAccess = data['access'] as String?;
      if (newAccess != null && newAccess.isNotEmpty) {
        await storage.saveAccessToken(newAccess);
        return true;
      }
      return false;
    } catch (_) {
      // Refresh failed — clear tokens so user is sent to login.
      await StorageService().clearAllTokens();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }
}
