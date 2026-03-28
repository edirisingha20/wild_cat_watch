import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/sightings_service.dart';
import '../sightings/models/alert_model.dart';

/// Radius in metres that matches the backend NEARBY_SIGHTING_RADIUS_KM (5 km).
const double kNearbySightingRadiusMeters = 5000;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SightingsService _sightingsService = SightingsService();
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = <Marker>{};
  Set<Circle> _circles = <Circle>{};
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasNearbySightings = true;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      final LatLng currentLocation = LatLng(position.latitude, position.longitude);

      final List<Alert> nearbyAlerts = await _sightingsService.fetchNearbySightings(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
      );

      final Set<Marker> markers = <Marker>{
        Marker(
          markerId: const MarkerId('user_location'),
          position: currentLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      };

      final Set<Circle> circles = <Circle>{};
      for (final Alert alert in nearbyAlerts) {
        markers.add(
          Marker(
            markerId: MarkerId(alert.id.toString()),
            position: LatLng(alert.latitude, alert.longitude),
            infoWindow: InfoWindow(
              title: 'Leopard Alert',
              snippet: alert.locationName,
            ),
          ),
        );

        circles.add(
          Circle(
            circleId: CircleId(alert.id.toString()),
            center: LatLng(alert.latitude, alert.longitude),
            radius: kNearbySightingRadiusMeters,
            fillColor: Colors.red.withValues(alpha: 0.2),
            strokeColor: Colors.red,
            strokeWidth: 2,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = currentLocation;
        _markers = markers;
        _circles = circles;
        _hasNearbySightings = nearbyAlerts.isNotEmpty;
        _isLoading = false;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation, 14),
      );
    } on LocationServiceException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = ApiService.buildErrorMessage(
          e,
          fallbackMessage: 'Failed to load nearby sightings',
        );
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMapData,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.9271, 79.8612),
              zoom: 12,
            ),
            myLocationEnabled: _currentPosition != null,
            myLocationButtonEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _markers,
            circles: _circles,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            _StatusBanner(
              message: _errorMessage!,
              actionLabel: 'Retry',
              onPressed: _loadMapData,
            )
          else if (!_isLoading && !_hasNearbySightings)
            _StatusBanner(
              message: 'No nearby sightings found',
              actionLabel: 'Refresh',
              onPressed: _loadMapData,
            ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Colors.white,
        child: Row(
          children: <Widget>[
            Expanded(child: Text(message)),
            TextButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
