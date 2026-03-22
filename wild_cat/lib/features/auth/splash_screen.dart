import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/main_navigation_screen.dart';
import 'auth_provider.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    final AuthProvider authProvider = context.read<AuthProvider>();

    final bool restored = await authProvider.restoreSession();

    if (!mounted) {
      return;
    }

    final Widget destination =
        restored ? const MainNavigationScreen() : const LoginScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }
}
