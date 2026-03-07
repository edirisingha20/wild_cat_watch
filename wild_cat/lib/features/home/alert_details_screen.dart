import 'package:flutter/material.dart';

import '../sightings/models/alert_model.dart';

class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({
    super.key,
    required this.alert,
  });

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(alert.description),
            const SizedBox(height: 8),
            Text('Location: ${alert.locationName}'),
            const SizedBox(height: 8),
            Text('Reported: ${_formatDateTime(alert.createdAt)}'),
            const SizedBox(height: 16),
            Text('Latitude: ${alert.latitude}'),
            const SizedBox(height: 8),
            Text('Longitude: ${alert.longitude}'),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String mm = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String hh = local.hour.toString().padLeft(2, '0');
    final String min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }
}
