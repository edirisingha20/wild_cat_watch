import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../profile/models/user_profile.dart';
import 'models/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    StorageService? storageService,
    ProfileService? profileService,
  })  : _authService = authService ?? AuthService(),
        _storageService = storageService ?? StorageService(),
        _profileService = profileService ?? ProfileService();

  final AuthService _authService;
  final StorageService _storageService;
  final ProfileService _profileService;

  bool isLoading = false;
  String? errorMessage;
  AuthUser? currentUser;

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
      final String? refreshToken = data['refresh'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        errorMessage = 'Access token missing in response.';
        return false;
      }

      await _storageService.saveAccessToken(accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storageService.saveRefreshToken(refreshToken);
      }

      // Fetch real profile from backend.
      await _loadUserProfile(fallbackIdentifier: identifier);

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

  /// Restore session from stored tokens. Returns true if session is valid.
  Future<bool> restoreSession() async {
    final String? token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      await _loadUserProfile();
      return currentUser != null;
    } on DioException catch (e) {
      // Only clear tokens if the server explicitly rejected them.
      if (e.response?.statusCode == 401) {
        await _storageService.clearAllTokens();
      }
      return false;
    } catch (_) {
      // Network errors, timeouts, etc. — don't clear tokens, just fail silently.
      return false;
    }
  }

  Future<void> logout() async {
    await _storageService.clearAllTokens();
    currentUser = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _loadUserProfile({String? fallbackIdentifier}) async {
    try {
      final UserProfile profile = await _profileService.getProfile();
      currentUser = AuthUser(
        fullName: profile.fullName.isNotEmpty ? profile.fullName : 'Wild Cat User',
        username: profile.username,
        email: profile.email,
        designation: profile.designation.isNotEmpty ? profile.designation : 'Community Member',
      );
    } catch (_) {
      // If profile fetch fails, use fallback data so login still works.
      if (fallbackIdentifier != null) {
        currentUser = _buildUserFromIdentifier(fallbackIdentifier);
      }
    }
  }

  AuthUser _buildUserFromIdentifier(String identifier) {
    final bool isEmail = identifier.contains('@');
    return AuthUser(
      fullName: 'Wild Cat User',
      username: isEmail ? identifier.split('@').first : identifier,
      email: isEmail ? identifier : 'Not available',
      designation: 'Community Member',
    );
  }
}
