import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../services/backend_discovery_service.dart';
import 'app_config.dart';

/// Holds the base URL the app uses to reach the backend, resolved at runtime.
///
/// On startup — and whenever the network changes — it tries to discover the
/// backend on the LAN via mDNS ([BackendDiscoveryService]). If discovery
/// succeeds, all requests use the discovered address; otherwise it falls back
/// to the static value from `.env` ([AppConfig.normalizedApiBaseUrl]).
///
/// This is what makes the app keep working when you switch Wi-Fi networks
/// without editing config or rebuilding.
class BackendResolver {
  BackendResolver._();

  static final BackendResolver instance = BackendResolver._();

  final BackendDiscoveryService _discovery = BackendDiscoveryService();

  String _baseUrl = AppConfig.normalizedApiBaseUrl;

  /// The current backend base URL. Always safe to read synchronously.
  String get baseUrl => _baseUrl;

  bool _initialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Run one discovery pass and start listening for network changes.
  /// Safe to call multiple times; only the first call has an effect.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _resolve();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> _) {
      // Network changed (e.g. switched Wi-Fi) — re-discover the backend.
      _resolve();
    });
  }

  /// Force a fresh discovery pass (e.g. after a manual retry).
  Future<void> refresh() => _resolve();

  Future<void> _resolve() async {
    final String? discovered = await _discovery.discover();
    if (discovered != null && discovered.isNotEmpty) {
      _baseUrl = discovered;
      debugPrint('BackendResolver: using discovered backend $_baseUrl');
    } else {
      debugPrint('BackendResolver: no backend discovered, keeping $_baseUrl');
    }
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _initialized = false;
  }
}
