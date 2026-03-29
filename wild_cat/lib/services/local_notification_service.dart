import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps [FlutterLocalNotificationsPlugin] for use in Wild Cat Watch.
///
/// Responsibilities:
///   - Create the Android notification channel on first run.
///   - Show a high-priority popup notification when an FCM message arrives
///     while the app is in the foreground (replaces the old Snackbar).
///   - Invoke [onTap] when the user taps a notification.
class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Channel configuration ─────────────────────────────────────────────────
  static const String _channelId = 'wild_cat_alerts';
  static const String _channelName = 'Leopard Alerts';
  static const String _channelDesc =
      'Real-time alerts for nearby leopard sightings.';

  bool _initialized = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialize the service. Must be called once before [showAlert].
  ///
  /// [onTap] is called with the notification payload (sighting_id string or
  /// null) whenever the user taps a local notification.
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_notification');

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTap,
    );

    // Create the channel on Android (safe to call repeatedly — no-op if
    // the channel already exists with the same ID).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );

    _initialized = true;
    debugPrint('LocalNotificationService initialized.');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Show a high-priority popup notification.
  ///
  /// [payload] is passed back to [onTap] when the user taps the notification.
  /// Typically this is the sighting_id from the FCM data payload.
  Future<void> showAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      debugPrint('LocalNotificationService.showAlert: not initialized, skipping.');
      return;
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Leopard Alert',
      icon: 'ic_notification',
      // BigTextStyle shows the full body text without truncation.
      styleInformation: BigTextStyleInformation(body),
    );

    try {
      await _plugin.show(
        // Use seconds-since-epoch as a simple unique ID. Avoids int32 overflow
        // while ensuring different sightings get different IDs.
        DateTime.now().millisecondsSinceEpoch ~/ 1000 % 2147483647,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('LocalNotificationService.showAlert error: $e');
    }
  }
}

/// Top-level callback required by flutter_local_notifications for background
/// notification taps (app was in background when user tapped the notification).
/// Must be a top-level function and annotated with [pragma].
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  // The stream dispatch can't reach the main isolate from here.
  // Navigation is handled by FCM's onMessageOpenedApp in main.dart instead.
  debugPrint(
    'LocalNotificationService: background tap payload=${response.payload}',
  );
}
