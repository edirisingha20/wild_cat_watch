import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const WildCatWatchApp());
}

class WildCatWatchApp extends StatelessWidget {
  const WildCatWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Wild Cat Watch',
        home: const LoginScreen(),
      ),
    );
  }
}
