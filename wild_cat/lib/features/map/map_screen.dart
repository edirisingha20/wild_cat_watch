import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/sightings_service.dart';
import '../sightings/models/alert_model.dart';

/// Radius in metres — must match backend `NEARBY_SIGHTING_RADIUS_KM` (5 km).
const double kNearbySightingRadiusMeters = 5000;

/// Fallback camera position used when GPS is unavailable (central Sri Lanka).
const LatLng _kFallbackLocation = LatLng(6.9271, 79.8612);

// ── Widget ────────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  /// Normal mode (no arguments): camera centres on current GPS position.
  ///
  /// Focused mode ([focusAlert] provided): camera immediately centres on
  /// that sighting's coordinates with a marker and 5 km danger circle.
  /// Used by AlertDetailsScreen → "View on Map".
  const MapScreen({super.key, this.focusAlert});

  final Alert? focusAlert;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// ── State ─────────────────────────────────────────────────────────────────────

class _MapScreenState extends State<MapScreen> {
  final SightingsService _sightingsService = SightingsService();
  final LocationService _locationService = LocationService();

  /// Completer that resolves as soon as [GoogleMap.onMapCreated] fires.
  /// Awaiting this guarantees [animateCamera] is never called on a null
  /// controller, regardless of how fast or slow the network responds.
  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();

  LatLng? _currentPosition; // drives the blue "My Location" dot
  Set<Marker> _markers = <Marker>{};
  Set<Circle> _circles = <Circle>{};
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasNearbySightings = true;

  bool get _isFocusMode => widget.focusAlert != null;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    if (_isFocusMode) {
      // KEY FIX: add the focus-alert marker and circle SYNCHRONOUSLY so they
      // are visible from frame 1, without waiting for any network call.
      _applyFocusAlertMarker();
    }

    _loadMapData();
  }

  @override
  void dispose() {
    // Complete the completer with a dummy value to avoid leaking futures if
    // the user navigates away before onMapCreated fires.
    if (!_controllerCompleter.isCompleted) {
      _controllerCompleter.completeError('disposed');
    }
    super.dispose();
  }

  // ── Immediate focus marker (called synchronously from initState) ─────────────

  /// Populates [_markers] and [_circles] with the focus alert immediately so
  /// the map renders the pin and danger circle on the very first frame.
  void _applyFocusAlertMarker() {
    final Alert fa = widget.focusAlert!;
    final LatLng pos = LatLng(fa.latitude, fa.longitude);

    _markers = <Marker>{
      Marker(
        markerId: MarkerId(fa.id.toString()),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: '📍 This Sighting',
          snippet: fa.locationName,
        ),
      ),
    };

    _circles = <Circle>{
      Circle(
        circleId: CircleId(fa.id.toString()),
        center: pos,
        radius: kNearbySightingRadiusMeters,
        fillColor: Colors.red.withValues(alpha: 0.15),
        strokeColor: Colors.red,
        strokeWidth: 3,
      ),
    };

    // Not empty — the focus alert is always considered a "sighting".
    _hasNearbySightings = true;
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // ── 1. Determine the query centre ─────────────────────────────────────────
    LatLng queryLatLng;
    bool gpsAvailable = false;

    if (_isFocusMode) {
      // In focused mode the centre is the alert — GPS runs in the background.
      queryLatLng = LatLng(
        widget.focusAlert!.latitude,
        widget.focusAlert!.longitude,
      );
    } else {
      // Normal mode: try GPS, fall back to the default position.
      try {
        final Position position = await _locationService.getCurrentLocation();
        queryLatLng = LatLng(position.latitude, position.longitude);
        gpsAvailable = true;
      } on LocationServiceException catch (e) {
        queryLatLng = _kFallbackLocation;
        if (mounted) setState(() => _errorMessage = e.message);
      }
    }

    // ── 2. Fetch nearby sightings ─────────────────────────────────────────────
    try {
      final List<Alert> nearby = await _sightingsService.fetchNearbySightings(
        latitude: queryLatLng.latitude,
        longitude: queryLatLng.longitude,
      );

      if (!mounted) return;

      final Set<Marker> markers = <Marker>{};
      final Set<Circle> circles = <Circle>{};

      // User location marker (normal mode, GPS succeeded).
      if (gpsAvailable) {
        markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: queryLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        );
      }

      // Build sighting markers and danger circles.
      final int? focusId = widget.focusAlert?.id;
      for (final Alert alert in nearby) {
        final bool isFocus = alert.id == focusId;
        markers.add(
          Marker(
            markerId: MarkerId(alert.id.toString()),
            position: LatLng(alert.latitude, alert.longitude),
            icon: isFocus
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  )
                : BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: isFocus ? '📍 This Sighting' : 'Leopard Alert',
              snippet: alert.locationName,
            ),
          ),
        );
        circles.add(
          Circle(
            circleId: CircleId(alert.id.toString()),
            center: LatLng(alert.latitude, alert.longitude),
            radius: kNearbySightingRadiusMeters,
            fillColor: Colors.red.withValues(
              alpha: isFocus ? 0.15 : 0.08,
            ),
            strokeColor: isFocus ? Colors.red : Colors.redAccent,
            strokeWidth: isFocus ? 3 : 2,
          ),
        );
      }

      // Edge-case: focus alert is outside the 5 km radius of itself — impossible
      // in practice but handled defensively so the marker is never missing.
      if (focusId != null && !nearby.any((Alert a) => a.id == focusId)) {
        final Alert fa = widget.focusAlert!;
        markers.add(
          Marker(
            markerId: MarkerId(fa.id.toString()),
            position: LatLng(fa.latitude, fa.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: '📍 This Sighting',
              snippet: fa.locationName,
            ),
          ),
        );
        circles.add(
          Circle(
            circleId: CircleId(fa.id.toString()),
            center: LatLng(fa.latitude, fa.longitude),
            radius: kNearbySightingRadiusMeters,
            fillColor: Colors.red.withValues(alpha: 0.15),
            strokeColor: Colors.red,
            strokeWidth: 3,
          ),
        );
      }

      setState(() {
        _currentPosition = gpsAvailable ? queryLatLng : null;
        _markers = markers;
        _circles = circles;
        _hasNearbySightings = nearby.isNotEmpty || focusId != null;
        _isLoading = false;
      });

      // ── 3. Animate camera — wait for controller no matter how fast the API
      //       is. The Completer guarantees we never call animateCamera on null.
      try {
        final GoogleMapController ctrl =
            await _controllerCompleter.future.timeout(
          const Duration(seconds: 10),
        );
        await ctrl.animateCamera(
          CameraUpdate.newLatLngZoom(queryLatLng, 14),
        );
      } catch (_) {
        // Controller timed-out (very unlikely) or widget was disposed.
        // The map is already visible at the correct initial position.
      }

      // ── 4. Load user location in focused mode AFTER sighting markers are set.
      //       This prevents the GPS race condition that could wipe markers.
      if (_isFocusMode) {
        _loadUserLocationInBackground();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage ??= ApiService.buildErrorMessage(
          e,
          fallbackMessage: 'Failed to load nearby sightings',
        );
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage ??= e.toString();
        _isLoading = false;
      });
    }
  }

  /// Adds the "Your Location" marker after sighting markers are already set.
  /// Called only in focused mode, after [_loadMapData]'s setState, so the
  /// GPS result can never overwrite or race with the sighting markers.
  void _loadUserLocationInBackground() {
    _locationService.getCurrentLocation().then((Position pos) {
      if (!mounted) return;
      final LatLng userPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentPosition = userPos;
        // Merge: add user marker while keeping all existing sighting markers.
        _markers = <Marker>{
          Marker(
            markerId: const MarkerId('user_location'),
            position: userPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
          ..._markers.where(
            (Marker m) => m.markerId.value != 'user_location',
          ),
        };
      });
    }).catchError((Object _) {
      // GPS unavailable — user location marker simply omitted.
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Determine the initial camera target:
    // focused mode → alert location; normal mode → Sri Lanka fallback.
    final LatLng initialTarget = _isFocusMode
        ? LatLng(
            widget.focusAlert!.latitude,
            widget.focusAlert!.longitude,
          )
        : _kFallbackLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isFocusMode ? 'Sighting Location' : 'Map'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMapData,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          // ── Google Map ───────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14, // Start at 14 so the marker is immediately prominent.
            ),
            myLocationEnabled: _currentPosition != null,
            myLocationButtonEnabled: _currentPosition != null,
            onMapCreated: (GoogleMapController controller) {
              // Complete the Completer so any pending animateCamera call
              // that was already awaiting it will proceed immediately.
              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(controller);
              }
            },
            markers: _markers,
            circles: _circles,
          ),

          // ── Loading overlay ──────────────────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),

          // ── Status banners ───────────────────────────────────────────────────
          if (_errorMessage != null)
            _StatusBanner(
              message: _errorMessage!,
              actionLabel: 'Retry',
              onPressed: _loadMapData,
            )
          else if (!_isLoading && !_hasNearbySightings)
            const _StatusBanner(
              message: 'No nearby sightings found',
            ),
        ],
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            if (actionLabel != null && onPressed != null)
              TextButton(
                onPressed: onPressed,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
