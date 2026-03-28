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

    await _apiService.post(
      'users/device-token/',
      data: <String, dynamic>{'token': deviceToken},
    );
  }

  /// Listen for FCM token refreshes and re-register with the backend.
  void listenForTokenRefresh() {
    if (Firebase.apps.isEmpty) {
      debugPrint('Skipping FCM token-refresh listener because Firebase is not initialized.');
      return;
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      debugPrint('FCM token refreshed, registering with backend...');
      try {
        await _apiService.post(
          'users/device-token/',
          data: <String, dynamic>{'token': newToken},
        );
        debugPrint('Refreshed FCM token registered successfully.');
      } catch (e) {
        debugPrint('Failed to register refreshed FCM token: $e');
      }
    });
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
