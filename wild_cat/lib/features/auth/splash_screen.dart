import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/navigation/main_navigation_screen.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final StorageService _storageService = StorageService();
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    final String? accessToken = await _storageService.getAccessToken();

    Widget destination = const LoginScreen();

    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        await _profileService.getProfile().timeout(const Duration(seconds: 5));
        destination = const MainNavigationScreen();
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          await _storageService.clearAccessToken();
        }
      } on TimeoutException {
        await _storageService.clearAccessToken();
      } catch (_) {
        await _storageService.clearAccessToken();
      }
    }

    if (!mounted) {
      return;
    }

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
