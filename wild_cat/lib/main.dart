import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/notification_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/splash_screen.dart';
import 'firebase_options.dart';
import 'services/local_notification_service.dart';
import 'services/notification_service.dart';

// ── Global keys ──────────────────────────────────────────────────────────────

/// Used by [ScaffoldMessenger] for app-wide snackbars (kept for non-notification use).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Used to navigate from notification tap callbacks that lack a [BuildContext].
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

// ── Background FCM handler ────────────────────────────────────────────────────
// Must be a top-level function.  FCM calls this in a separate isolate when
// the app is not in the foreground.  The system tray notification is shown
// automatically by FCM; no extra work is needed here.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
}

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Firebase must be initialized before registering the background handler.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const WildCatWatchApp());

  // Notification setup runs after the widget tree is built so that the
  // navigator key is attached before we attempt any navigation.
  unawaited(_initializeNotifications());
}

// ── Notification bootstrap ────────────────────────────────────────────────────

Future<void> _initializeNotifications() async {
  final NotificationService fcmService = NotificationService();
  final LocalNotificationService localService = LocalNotificationService();

  try {
    // 1. Initialise local notifications with a tap handler.
    await localService.initialize(
      onTap: (String? payload) {
        // User tapped a foreground local notification → go to Home tab.
        dispatchNotificationOpened();
      },
    );

    // 2. Request OS notification permission (shows system dialog on first run).
    await fcmService.requestNotificationPermission();

    // 3. Foreground FCM messages → show as local notification popup instead
    //    of a Snackbar.
    fcmService.listenForegroundMessages(
      onMessage: (RemoteMessage message) {
        final String title =
            message.notification?.title ?? 'Leopard Alert';
        final String body = message.notification?.body ?? '';
        final String? sightingId = message.data['sighting_id'];

        localService.showAlert(
          title: title,
          body: body,
          payload: sightingId,
        );
      },
    );

    // 4. Keep FCM token fresh.
    fcmService.listenForTokenRefresh();

    // 5. App was in background and user tapped the FCM system tray notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification opened app from background.');
      dispatchNotificationOpened();
    });

    // 6. App was fully terminated and user tapped the notification to launch.
    //    Wait a moment so the widget tree is ready before navigating.
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from FCM notification tap.');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      dispatchNotificationOpened();
    }
  } catch (e) {
    // Notification setup must never crash the app.
    debugPrint('Notification initialization skipped: $e');
  }
}

// ── App widget ────────────────────────────────────────────────────────────────

class WildCatWatchApp extends StatelessWidget {
  const WildCatWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Wild Cat Watch',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
