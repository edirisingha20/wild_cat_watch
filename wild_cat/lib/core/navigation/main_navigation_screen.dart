import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/home/home_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/sightings/report_sighting_screen.dart';
import '../../services/api_service.dart';
import '../../services/location_api_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../notification_router.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final LocationService _locationService = LocationService();
  final LocationApiService _locationApiService = LocationApiService();
  final NotificationService _notificationService = NotificationService();

  late int _currentIndex;
  StreamSubscription<void>? _notifOpenedSub;

  late final List<Widget> _screens = <Widget>[
    const HomeScreen(),
    const MapScreen(),
    const ReportSightingScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // When a notification is tapped, switch to the Home tab so the user sees
    // the latest alerts.  HomeScreen also subscribes and auto-refreshes.
    _notifOpenedSub = notificationOpenedStream.listen((_) {
      if (mounted) setState(() => _currentIndex = 0);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUserLocationOnEntry();
      _registerDeviceTokenOnEntry();
    });
  }

  @override
  void dispose() {
    _notifOpenedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location_alt_outlined),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserLocationOnEntry() async {
    try {
      final Position position = await _locationService.getCurrentLocation();
      debugPrint('User location: ${position.latitude} , ${position.longitude}');
      await _locationApiService.updateUserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceException catch (e) {
      _showMessage(e.message);
    } on DioException catch (e) {
      _showMessage(
        ApiService.buildErrorMessage(
          e,
          fallbackMessage: 'Failed to update user location',
        ),
      );
    } catch (_) {
      _showMessage('Failed to update user location');
    }
  }

  Future<void> _registerDeviceTokenOnEntry() async {
    try {
      await _notificationService.registerDeviceTokenToBackend();
    } on DioException catch (e) {
      _showMessage(
        ApiService.buildErrorMessage(
          e,
          fallbackMessage: 'Failed to register notification token',
        ),
      );
    } catch (_) {
      _showMessage('Failed to register notification token');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
