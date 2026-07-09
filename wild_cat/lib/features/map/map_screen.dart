import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/profile_service.dart';
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
  final ProfileService _profileService = ProfileService();

  /// User's preferred alert radius (km); refreshed from the profile on load.
  double _radiusKm = 5;

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

    // ── 2. Fetch radius preference + nearby + own sightings ───────────────────
    try {
      // Preferred radius drives the single "alert zone" circle.
      try {
        final profile = await _profileService.getProfile();
        _radiusKm = profile.sightingRadiusKm;
      } catch (_) {
        // Non-fatal — keep the previous/default radius.
      }

      final List<Alert> nearby = await _sightingsService.fetchNearbySightings(
        latitude: queryLatLng.latitude,
        longitude: queryLatLng.longitude,
      );

      // Own reports — lets us show the user's last-7-day sightings in a
      // distinct colour, even if just outside the radius.
      List<Alert> mine = <Alert>[];
      try {
        mine = await _sightingsService.fetchMySightings();
      } catch (_) {
        // Non-fatal: skip the own-sightings overlay if unavailable.
      }

      if (!mounted) return;

      final int? focusId = widget.focusAlert?.id;

      // De-duplicate by id; own recent reports take precedence for colouring.
      final Map<int, Alert> byId = <int, Alert>{};
      for (final Alert a in nearby) {
        byId[a.id] = a;
      }
      for (final Alert a in mine.where((Alert a) => a.isRecentlyMine)) {
        byId[a.id] = a;
      }

      final Set<Marker> markers = <Marker>{};

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

      // Colour-coded sighting markers: green = your recent report, red = others.
      for (final Alert alert in byId.values) {
        final bool ownRecent = alert.isRecentlyMine;
        markers.add(
          Marker(
            markerId: MarkerId(alert.id.toString()),
            position: LatLng(alert.latitude, alert.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              ownRecent ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: ownRecent
                  ? 'My Report'
                  : (alert.id == focusId ? '📍 This Sighting' : 'Leopard Alert'),
              snippet: alert.locationName,
            ),
          ),
        );
      }

      // Ensure the focused sighting is always shown, even if out of range.
      if (focusId != null && !byId.containsKey(focusId)) {
        final Alert fa = widget.focusAlert!;
        markers.add(
          Marker(
            markerId: MarkerId(fa.id.toString()),
            position: LatLng(fa.latitude, fa.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: '📍 This Sighting',
              snippet: fa.locationName,
            ),
          ),
        );
      }

      // Single "alert zone" circle (your radius), centred on you — or on the
      // sighting in focus mode. Replaces the old cluttered per-sighting circles.
      final LatLng circleCenter = _isFocusMode
          ? LatLng(widget.focusAlert!.latitude, widget.focusAlert!.longitude)
          : queryLatLng;
      final Set<Circle> circles = <Circle>{
        Circle(
          circleId: const CircleId('alert_zone'),
          center: circleCenter,
          radius: _radiusKm * 1000,
          fillColor: Colors.red.withValues(alpha: 0.08),
          strokeColor: Colors.redAccent,
          strokeWidth: 2,
        ),
      };

      setState(() {
        _currentPosition = gpsAvailable ? queryLatLng : null;
        _markers = markers;
        _circles = circles;
        _hasNearbySightings = byId.isNotEmpty || focusId != null;
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
            padding: const EdgeInsets.only(bottom: 96, top: 8),
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
              color: Colors.black.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Colors.black26, blurRadius: 12),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Text('Loading sightings…'),
                  ],
                ),
              ),
            ),

          // ── Status banners ───────────────────────────────────────────────────
          if (_errorMessage != null)
            _StatusBanner(
              message: _errorMessage!,
              icon: Icons.error_outline,
              iconColor: AppColors.danger,
              actionLabel: 'Retry',
              onPressed: _loadMapData,
            )
          else if (!_isLoading && !_hasNearbySightings)
            const _StatusBanner(
              message: 'No nearby sightings found',
            ),

          // ── Legend ───────────────────────────────────────────────────────────
          if (!_isLoading)
            const Align(
              alignment: Alignment.bottomLeft,
              child: _MapLegend(),
            ),
        ],
      ),
    );
  }
}

// ── Legend ──────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'LEGEND',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 6),
          _LegendRow(color: Colors.red, label: 'Leopard sighting'),
          _LegendRow(color: Colors.green, label: 'Your recent report'),
          _LegendRow(color: Colors.blue, label: 'Your location'),
          _LegendRow(
            color: AppColors.danger,
            label: 'Alert radius',
            isRing: true,
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    this.isRing = false,
  });

  final Color color;
  final String label;
  final bool isRing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isRing ? color.withValues(alpha: 0.12) : color,
              shape: isRing ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isRing ? BorderRadius.circular(3) : null,
              border: isRing ? Border.all(color: color, width: 1.5) : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
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
    this.icon = Icons.info_outline,
    this.iconColor = AppColors.amber,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: Text(message)),
              if (actionLabel != null && onPressed != null)
                TextButton(
                  onPressed: onPressed,
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
