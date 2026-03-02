import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    StorageService? storageService,
  })  : _authService = authService ?? AuthService(),
        _storageService = storageService ?? StorageService();

  final AuthService _authService;
  final StorageService _storageService;

  bool isLoading = false;
  String? errorMessage;

  Future<bool> login(String identifier, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> data = await _authService.login(
        identifier: identifier,
        password: password,
      );

      final String? accessToken = data['access'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        errorMessage = 'Access token missing in response.';
        return false;
      }

      await _storageService.saveToken(accessToken);
      return true;
    } on DioException catch (e) {
      final dynamic responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        errorMessage = responseData['detail']?.toString() ??
            responseData['message']?.toString() ??
            'Login failed.';
      } else {
        errorMessage = 'Login failed.';
      }
      return false;
    } catch (_) {
      errorMessage = 'Unexpected error occurred.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.register(userData);
      return true;
    } on DioException catch (e) {
      final dynamic responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        errorMessage = responseData['detail']?.toString() ??
            responseData['message']?.toString() ??
            'Registration failed.';
      } else {
        errorMessage = 'Registration failed.';
      }
      return false;
    } catch (_) {
      errorMessage = 'Unexpected error occurred.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
