import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notification_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/sighting_thumbnail.dart';
import '../../core/widgets/status_views.dart';
import '../../services/sightings_service.dart';
import '../auth/auth_provider.dart';
import '../auth/models/auth_user.dart';
import '../map/map_screen.dart';
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
    final AuthUser? user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _DashboardHeader(user: user)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                sliver: const SliverToBoxAdapter(
                  child: SectionTitle(
                    title: 'Recent Leopard Sightings',
                    icon: Icons.pets,
                  ),
                ),
              ),
              _buildSightingsSliver(),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReportSightingScreen(),
            ),
          );
          _refresh();
        },
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Report'),
      ),
    );
  }

  Widget _buildSightingsSliver() {
    return FutureBuilder<List<Alert>>(
      future: _alertsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Alert>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: LoadingView(message: 'Loading sightings…'),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: ErrorStateView(
                message: 'Failed to load sightings',
                onRetry: _refresh,
              ),
            ),
          );
        }

        final List<Alert> alerts = snapshot.data ?? <Alert>[];
        if (alerts.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyStateView(
                icon: Icons.travel_explore_outlined,
                title: 'No sightings yet',
                message:
                    'Reported leopard sightings will appear here. Pull down to refresh.',
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: alerts.length,
            separatorBuilder: (_, _) => AppSpacing.gapMd,
            itemBuilder: (BuildContext context, int index) {
              return _SightingCard(
                alert: alerts[index],
                onViewDetails: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlertDetailsScreen(alert: alerts[index]),
                  ),
                ),
                onViewOnMap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MapScreen(focusAlert: alerts[index]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Dashboard header ──────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.forestGreen, AppColors.forestGreenDark],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _greeting(),
                      style: text.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.fullName ?? 'Officer',
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: <Widget>[
                _HeaderChip(
                  icon: Icons.apartment_outlined,
                  label: user?.departmentName ?? 'Wildlife Department',
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                _HeaderChip(
                  icon: Icons.calendar_today_outlined,
                  label: _formatToday(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  static String _formatToday() {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final DateTime now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sighting card ─────────────────────────────────────────────────────────────

class _SightingCard extends StatelessWidget {
  const _SightingCard({
    required this.alert,
    required this.onViewDetails,
    required this.onViewOnMap,
  });

  final Alert alert;
  final VoidCallback onViewDetails;
  final VoidCallback onViewOnMap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SightingThumbnail(imageUrl: alert.image, width: 76, height: 76),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.location_on,
                                    size: 15,
                                    color: AppColors.forestGreen,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      alert.locationName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (alert.isMine)
                              const AppBadge(
                                label: 'Your report',
                                color: AppColors.olive,
                                icon: Icons.person_outline,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.schedule,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _timeAgo(alert.createdAt),
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          alert.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Details'),
                    ),
                  ),
                  Container(width: 1, height: 24, color: AppColors.border),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onViewOnMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('View on Map'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime createdAt) {
    final Duration diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
