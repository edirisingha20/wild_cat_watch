import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/splash_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialize Firebase before anything else that depends on it.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const WildCatWatchApp());
  unawaited(_initializeNotifications());
}

Future<void> _initializeNotifications() async {
  final NotificationService notificationService = NotificationService();

  try {
    await notificationService.requestNotificationPermission();
    notificationService.listenForegroundMessages(
      onMessage: (message) {
        final String notificationTitle = message.notification?.title ?? 'Alert';
        final String notificationBody = message.notification?.body ?? '';
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('$notificationTitle\n$notificationBody')),
        );
      },
    );
    notificationService.listenForTokenRefresh();
  } catch (e) {
    // FCM setup should not block app startup in non-configured environments.
    debugPrint('FCM initialization skipped: $e');
  }
}

class WildCatWatchApp extends StatelessWidget {
  const WildCatWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: MaterialApp(
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
