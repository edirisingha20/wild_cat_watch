import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  StorageService._internal();

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> saveAccessToken(String token) async {
    await saveToken(token);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getAccessToken() async {
    return getToken();
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> clearAccessToken() async {
    await clearToken();
  }

  Future<void> clearAllTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
