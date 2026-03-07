import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  StorageService._internal();

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  static const String _accessTokenKey = 'access_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _accessTokenKey);
  }
}
