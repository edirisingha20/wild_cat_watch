import 'package:flutter/material.dart';

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
  late final Future<List<Alert>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _sightingsService.fetchSightings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wild Cat Watch')),
      body: FutureBuilder<List<Alert>>(
        future: _alertsFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<Alert>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load alerts'));
          }

          final List<Alert> alerts = snapshot.data ?? <Alert>[];
          if (alerts.isEmpty) {
            return const Center(child: Text('No alerts available'));
          }

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (BuildContext context, int index) {
              final Alert alert = alerts[index];
              return ListTile(
                title: Text(alert.description),
                subtitle: Text(
                  '${alert.locationName} - ${_formatAlertTime(alert.createdAt)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlertDetailsScreen(alert: alert),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReportSightingScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatAlertTime(DateTime createdAt) {
    final Duration difference = DateTime.now().difference(createdAt.toLocal());
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    }
    return '${difference.inDays} days ago';
  }
}
