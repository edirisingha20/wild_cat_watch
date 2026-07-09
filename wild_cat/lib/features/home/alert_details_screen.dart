import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/info_tile.dart';
import '../map/map_screen.dart';
import '../sightings/models/alert_model.dart';

class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({super.key, required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _AlertImage(imageUrl: alert.image),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.location_on,
                          color: AppColors.forestGreen),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(alert.locationName, style: text.titleLarge),
                      ),
                      if (alert.isMine)
                        const AppBadge(
                          label: 'Your report',
                          color: AppColors.olive,
                          icon: Icons.person_outline,
                        ),
                    ],
                  ),
                  AppSpacing.gapLg,

                  // Description card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'DESCRIPTION',
                            style: text.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                          AppSpacing.gapSm,
                          Text(alert.description, style: text.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.gapLg,

                  // Info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Column(
                        children: <Widget>[
                          InfoTile(
                            icon: Icons.place_outlined,
                            label: 'Location',
                            value: alert.locationName,
                          ),
                          const Divider(height: 1),
                          InfoTile(
                            icon: Icons.access_time_outlined,
                            label: 'Reported',
                            value: _formatDateTime(alert.createdAt),
                          ),
                          const Divider(height: 1),
                          InfoTile(
                            icon: Icons.gps_fixed,
                            label: 'Coordinates',
                            value:
                                '${alert.latitude.toStringAsFixed(5)}, '
                                '${alert.longitude.toStringAsFixed(5)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  FilledButton.icon(
                    onPressed: () => _openOnMap(context),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on Map'),
                  ),
                  AppSpacing.gapSm,
                ],
              ),
            ),
          ),
        ],
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
    return '${local.year}-$mo-$dd  •  $hh:$mi';
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
      color: AppColors.oliveLight,
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  error
                      ? Icons.broken_image_outlined
                      : Icons.pets,
                  size: 56,
                  color: AppColors.forestGreenLight,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error ? 'Image unavailable' : 'No image',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }
}
