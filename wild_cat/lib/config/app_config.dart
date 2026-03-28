import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Local-network default for development on physical devices.
  static const String _defaultApiUrl = 'http://192.168.1.100:8000/api/';
  static const String _apiUrlFromDefine = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    final String fromDefine = _apiUrlFromDefine.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }

    final String fromDotEnv = (dotenv.env['API_URL'] ?? '').trim();
    if (fromDotEnv.isNotEmpty) {
      return fromDotEnv;
    }

    return _defaultApiUrl;
  }

  static String get normalizedApiBaseUrl {
    final String trimmed = apiBaseUrl.trim();
    if (trimmed.isEmpty) {
      return _defaultApiUrl;
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }
}
