import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/home/home_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../services/api_service.dart';
import '../../features/sightings/report_sighting_screen.dart';
import '../../services/location_api_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUserLocationOnEntry();
      _registerDeviceTokenOnEntry();
    });
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
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
      final double latitude = position.latitude;
      final double longitude = position.longitude;

      // Debug logging for development visibility.
      debugPrint('User location: $latitude , $longitude');

      await _locationApiService.updateUserLocation(
        latitude: latitude,
        longitude: longitude,
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
