import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../services/api_service.dart';
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
      errorMessage = ApiService.buildErrorMessage(
        e,
        fallbackMessage: 'Login failed.',
      );
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
      errorMessage = ApiService.buildErrorMessage(
        e,
        fallbackMessage: 'Registration failed.',
      );
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
  ///
  /// - 401 → tokens are invalid, clear them and return false.
  /// - Network / timeout error → keep tokens, retry once after a short delay,
  ///   then return false without clearing tokens so the user can try again.
  Future<bool> restoreSession() async {
    final String? token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        await _loadUserProfile();
        return currentUser != null;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          // Server explicitly rejected the token — clear and bail out.
          await _storageService.clearAllTokens();
          return false;
        }
        // Network error on first attempt — wait briefly and retry.
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        // Still failing after retry — keep tokens intact so a later attempt
        // can succeed once connectivity is restored.
        return false;
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        return false;
      }
    }
    return false;
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
