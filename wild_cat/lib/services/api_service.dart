import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  ApiService._internal() {
    if (kDebugMode) {
      debugPrint('ApiService base URL: ${AppConfig.normalizedApiBaseUrl}');
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.normalizedApiBaseUrl,
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

          if (kDebugMode) {
            debugPrint('API -> ${options.method} ${options.uri}');
          }

          handler.next(options);
        },
        onResponse: (Response<dynamic> response, ResponseInterceptorHandler handler) {
          if (kDebugMode) {
            final int? statusCode = response.statusCode;
            debugPrint('API <- [$statusCode] ${response.requestOptions.uri}');
          }
          handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401 &&
              !_isAuthPath(error.requestOptions.path)) {
            final bool refreshed = await _waitForTokenRefresh();
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
                if (kDebugMode) {
                  debugPrint(
                    'API !! ${retryError.type} ${retryError.requestOptions.uri}',
                  );
                }
                return handler.next(retryError);
              }
            }
          }
          if (kDebugMode) {
            debugPrint('API !! ${error.type} ${error.requestOptions.uri}');
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

  static const List<String> _publicPaths = <String>[
    'auth/login/',
    'auth/register/',
    'token/refresh/',
  ];

  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  static bool _isAuthPath(String path) {
    return path.contains('auth/login/') ||
        path.contains('auth/register/') ||
        path.contains('token/refresh/');
  }

  /// If a refresh is already in progress, wait for it instead of starting a
  /// second one.  This prevents concurrent refresh calls and queues requests
  /// that arrive while the token is being refreshed.
  Future<bool> _waitForTokenRefresh() async {
    if (_isRefreshing) {
      // Another call is already refreshing — wait for its result.
      return _refreshCompleter?.future ?? Future<bool>.value(false);
    }
    return _tryRefreshToken();
  }

  Future<bool> _tryRefreshToken() async {
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    try {
      final StorageService storage = StorageService();
      final String? refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final Response<dynamic> response = await Dio(
        BaseOptions(baseUrl: AppConfig.normalizedApiBaseUrl),
      ).post(
        'token/refresh/',
        data: <String, String>{'refresh': refreshToken},
      );

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(response.data as Map);
      final String? newAccess = data['access'] as String?;
      if (newAccess != null && newAccess.isNotEmpty) {
        await storage.saveAccessToken(newAccess);
        _refreshCompleter!.complete(true);
        return true;
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      // Refresh failed — clear tokens so user is sent to login.
      await StorageService().clearAllTokens();
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  static String buildErrorMessage(
    DioException error, {
    String fallbackMessage = 'Request failed.',
  }) {
    final DioExceptionType type = error.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.unknown) {
      return 'Cannot connect to server. Check network connection.';
    }
    if (type == DioExceptionType.badCertificate) {
      return 'Secure connection failed due to certificate issue.';
    }
    if (type == DioExceptionType.cancel) {
      return 'Request was cancelled.';
    }

    final dynamic responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final Object? detail = responseData['detail'] ?? responseData['message'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
      for (final Object? value in responseData.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          return value.first as String;
        }
      }
    }

    return fallbackMessage;
  }
}
