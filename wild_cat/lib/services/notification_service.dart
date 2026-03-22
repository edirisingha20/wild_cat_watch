import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'api_service.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final ApiService _apiService = ApiService();

  /// Ensures Firebase is initialized. Safe to call multiple times.
  /// In normal flow, Firebase.initializeApp is already called in main().
  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<NotificationSettings> requestNotificationPermission() async {
    await _ensureFirebaseInitialized();
    return FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<String?> getDeviceToken() async {
    await _ensureFirebaseInitialized();
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> registerDeviceTokenToBackend({int maxAttempts = 3}) async {
    String? deviceToken;
    Object? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        deviceToken = await getDeviceToken();
        if (deviceToken != null && deviceToken.isNotEmpty) {
          break;
        }
      } catch (e) {
        lastError = e;
        debugPrint('FCM token fetch failed (attempt $attempt/$maxAttempts): $e');
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    if (deviceToken == null || deviceToken.isEmpty) {
      if (lastError != null) {
        throw Exception('Unable to retrieve FCM token: $lastError');
      }
      return;
    }

    await _apiService.dio.post(
      'users/device-token/',
      data: <String, dynamic>{'token': deviceToken},
    );
  }

  void listenForegroundMessages({
    required void Function(RemoteMessage message) onMessage,
  }) {
    if (Firebase.apps.isEmpty) {
      debugPrint('Skipping foreground FCM listener because Firebase is not initialized.');
      return;
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Notification received: ${message.messageId}');
      onMessage(message);
    });
  }
}
