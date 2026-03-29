import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/notification_router.dart';
import '../../services/sightings_service.dart';
import '../sightings/models/alert_model.dart';
import '../sightings/report_sighting_screen.dart';
import 'alert_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SightingsService _sightingsService = SightingsService();
  late Future<List<Alert>> _alertsFuture;
  StreamSubscription<void>? _notifSub;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _sightingsService.fetchSightings();

    // When a notification is tapped the user is brought to this screen.
    // Auto-refresh so they immediately see the latest sighting.
    _notifSub = notificationOpenedStream.listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final Future<List<Alert>> fresh = _sightingsService.fetchSightings();
    setState(() => _alertsFuture = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wild Cat Watch')),
      body: FutureBuilder<List<Alert>>(
        future: _alertsFuture,
        builder: (BuildContext context, AsyncSnapshot<List<Alert>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Failed to load alerts'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final List<Alert> alerts = snapshot.data ?? <Alert>[];

          if (alerts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const <Widget>[
                  SizedBox(height: 200),
                  Center(child: Text('No alerts available')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: alerts.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (BuildContext context, int index) {
                final Alert alert = alerts[index];
                return _AlertListTile(
                  alert: alert,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlertDetailsScreen(alert: alert),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReportSightingScreen(),
            ),
          );
          _refresh();
        },
        tooltip: 'Report Sighting',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Alert list tile ───────────────────────────────────────────────────────────

class _AlertListTile extends StatelessWidget {
  const _AlertListTile({required this.alert, required this.onTap});

  final Alert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _Thumbnail(imageUrl: alert.image),
      title: Text(
        alert.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.location_on_outlined,
              size: 13,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                '${alert.locationName} · ${_timeAgo(alert.createdAt)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  static String _timeAgo(DateTime createdAt) {
    final Duration diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.green.shade50,
      alignment: Alignment.center,
      child: const Icon(Icons.pets, color: Colors.green, size: 28),
    );
  }
}
