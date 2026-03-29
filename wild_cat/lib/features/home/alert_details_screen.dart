import 'package:flutter/material.dart';

import '../map/map_screen.dart';
import '../sightings/models/alert_model.dart';

class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({super.key, required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Hero image ─────────────────────────────────────────────────
            _AlertImage(imageUrl: alert.image),

            // ── Content ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    alert.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),

                  // Info card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        children: <Widget>[
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: alert.locationName,
                          ),
                          const Divider(height: 1),
                          _InfoRow(
                            icon: Icons.access_time_outlined,
                            label: 'Reported',
                            value: _formatDateTime(alert.createdAt),
                          ),
                          const Divider(height: 1),
                          _InfoRow(
                            icon: Icons.gps_fixed,
                            label: 'Coordinates',
                            value:
                                '${alert.latitude.toStringAsFixed(5)},  '
                                '${alert.longitude.toStringAsFixed(5)}',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── "View on Map" button ──────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openOnMap(context),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View on Map'),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openOnMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(focusAlert: alert),
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String mo = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mi = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mo-$dd   $hh:$mi';
  }
}

// ── Hero image ────────────────────────────────────────────────────────────────

class _AlertImage extends StatelessWidget {
  const _AlertImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder();
    }
    return Image.network(
      imageUrl!,
      width: double.infinity,
      height: 260,
      fit: BoxFit.cover,
      loadingBuilder: (_, Widget child, ImageChunkEvent? progress) {
        if (progress == null) return child;
        return _placeholder(loading: true);
      },
      errorBuilder: (_, _, _) => _placeholder(error: true),
    );
  }

  Widget _placeholder({bool loading = false, bool error = false}) {
    return Container(
      width: double.infinity,
      height: 260,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  error
                      ? Icons.broken_image_outlined
                      : Icons.image_not_supported_outlined,
                  size: 56,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  error ? 'Image unavailable' : 'No image',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
