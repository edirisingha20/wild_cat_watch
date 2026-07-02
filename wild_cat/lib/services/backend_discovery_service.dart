import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

/// Finds the Wild Cat Watch backend on the local network via mDNS / DNS-SD.
///
/// The Django backend advertises a `_wildcat._tcp` service (see
/// backend/discovery/advertiser.py). On Android this uses the native
/// NsdManager under the hood, which handles the Wi-Fi multicast lock for us.
class BackendDiscoveryService {
  static const String _serviceType = '_wildcat._tcp';

  /// Returns a base URL such as `http://192.168.1.12:8000/api/` for the first
  /// backend found on the LAN, or `null` if none responds within [timeout].
  Future<String?> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    BonsoirDiscovery? discovery;
    StreamSubscription<BonsoirDiscoveryEvent>? subscription;
    final Completer<String?> completer = Completer<String?>();

    try {
      discovery = BonsoirDiscovery(type: _serviceType);
      await discovery.initialize();

      subscription = discovery.eventStream!.listen((BonsoirDiscoveryEvent event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          // A service appeared; ask the platform to resolve its address + port.
          discovery!.serviceResolver.resolveService(event.service);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final String? host = _pickHost(event.service);
          if (host != null && !completer.isCompleted) {
            completer.complete('http://$host:${event.service.port}/api/');
          }
        }
      });

      await discovery.start();
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (e) {
      debugPrint('BackendDiscoveryService: discovery failed: $e');
      return null;
    } finally {
      await subscription?.cancel();
      await discovery?.stop();
    }
  }

  /// Prefer an IPv4 address (Dio needs a routable host, not a `.local` name).
  static String? _pickHost(BonsoirService service) {
    for (final String addr in service.hostAddresses) {
      if (addr.contains('.') && !addr.contains(':')) {
        return addr;
      }
    }
    if (service.hostAddresses.isNotEmpty) {
      return service.hostAddresses.first;
    }
    final String? hostname = service.hostname;
    if (hostname != null && hostname.isNotEmpty) {
      return hostname.endsWith('.')
          ? hostname.substring(0, hostname.length - 1)
          : hostname;
    }
    return null;
  }
}
