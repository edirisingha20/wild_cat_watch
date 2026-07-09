import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/info_tile.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/sighting_thumbnail.dart';
import '../../core/widgets/status_views.dart';
import '../../services/api_service.dart';
import '../../services/organization_service.dart';
import '../../services/profile_service.dart';
import '../../services/sightings_service.dart';
import '../admin/admin_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../sightings/models/alert_model.dart';
import 'models/lookup_option.dart';
import 'models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final OrganizationService _organizationService = OrganizationService();
  final SightingsService _sightingsService = SightingsService();
  late Future<UserProfile> _profileFuture;
  late Future<List<Alert>> _mySightingsFuture;
  bool _isUpdating = false;
  double? _radiusKm; // local slider value, seeded from the profile
  bool _savingRadius = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.getProfile();
    _mySightingsFuture = _sightingsService.fetchMySightings();
  }

  Future<void> _saveRadius(double radiusKm) async {
    setState(() => _savingRadius = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await _profileService.updateRadius(radiusKm);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Alert radius set to ${radiusKm.round()} km')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ApiService.buildErrorMessage(e, fallbackMessage: 'Failed to update radius'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingRadius = false);
    }
  }

  Widget _buildProfileHeader(UserProfile profile) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
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
        children: <Widget>[
          AppAvatar(name: profile.fullName, radius: 40),
          AppSpacing.gapMd,
          Text(
            profile.fullName,
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            profile.position?.name ?? 'Officer',
            style: text.bodyMedium?.copyWith(color: Colors.white70),
          ),
          if (profile.department != null) ...<Widget>[
            AppSpacing.gapMd,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.apartment_outlined,
                      size: 15, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    profile.department!.name,
                    style: text.labelMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          children: <Widget>[
            InfoTile(
              icon: Icons.alternate_email,
              label: 'Username',
              value: profile.username,
            ),
            const Divider(height: 1),
            InfoTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: profile.email,
            ),
            const Divider(height: 1),
            InfoTile(
              icon: Icons.cake_outlined,
              label: 'Birthday',
              value: profile.birthday ?? '—',
            ),
            const Divider(height: 1),
            InfoTile(
              icon: Icons.military_tech_outlined,
              label: 'Position',
              value: profile.position?.name ?? '—',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(UserProfile profile) {
    return Card(
      color: AppColors.amberLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.amber.withValues(alpha: 0.2),
          child: const Icon(Icons.admin_panel_settings,
              color: Color(0xFFB26A00)),
        ),
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Manage users and reported sightings'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdminScreen(currentUserId: profile.id),
          ),
        ),
      ),
    );
  }

  Widget _buildRadiusCard(UserProfile profile) {
    final double radius = _radiusKm ??= profile.sightingRadiusKm;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.my_location,
                    size: 20, color: AppColors.forestGreen),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Alert Radius',
                    style:
                        text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.oliveLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${radius.round()} km',
                    style: text.labelLarge?.copyWith(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapXs,
            Text(
              'You only see sightings and receive alerts within this distance.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            Slider(
              value: radius.clamp(1, 50),
              min: 1,
              max: 50,
              divisions: 49,
              label: '${radius.round()} km',
              onChanged: _savingRadius
                  ? null
                  : (double value) => setState(() => _radiusKm = value),
              onChangeEnd: _savingRadius ? null : _saveRadius,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySightings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionTitle(
          title: 'My Reported Sightings',
          icon: Icons.assignment_outlined,
        ),
        AppSpacing.gapMd,
        FutureBuilder<List<Alert>>(
          future: _mySightingsFuture,
          builder: (BuildContext context, AsyncSnapshot<List<Alert>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'Failed to load your sightings.',
                style: TextStyle(color: AppColors.textSecondary),
              );
            }
            final List<Alert> sightings = snapshot.data ?? <Alert>[];
            if (sightings.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.info_outline,
                          color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          "You haven't reported any sightings yet.",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: <Widget>[
                for (final Alert alert in sightings) ...<Widget>[
                  _sightingTile(alert),
                  AppSpacing.gapSm,
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _sightingTile(Alert alert) {
    final String date = alert.createdAt.toLocal().toString().split('.').first;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
        leading: SightingThumbnail(imageUrl: alert.image, width: 52, height: 52),
        title: Text(
          alert.locationName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(date),
      ),
    );
  }

  Future<void> _showEditDialog(UserProfile profile) async {
    final TextEditingController fullNameController =
        TextEditingController(text: profile.fullName);
    final TextEditingController birthdayController =
        TextEditingController(text: profile.birthday ?? '');
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    int? selectedDepartmentId = profile.department?.id;
    int? selectedPositionId = profile.position?.id;
    Future<List<LookupOption>> positionsFuture = selectedDepartmentId == null
        ? Future<List<LookupOption>>.value(<LookupOption>[])
        : _organizationService.getPositions(selectedDepartmentId);

    List<LookupOption> departments;
    try {
      departments = await _organizationService.getDepartments();
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.buildErrorMessage(
              e,
              fallbackMessage: 'Failed to load departments',
            ),
          ),
        ),
      );
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load departments')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (
              BuildContext context,
              void Function(void Function()) setDialogState,
            ) {
              return AlertDialog(
                title: const Text('Edit Profile'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(labelText: 'Full Name'),
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter full name';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: birthdayController,
                          decoration: const InputDecoration(labelText: 'Birthday'),
                          readOnly: true,
                          onTap: () async {
                            final DateTime? selectedDate = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              initialDate: birthdayController.text.isNotEmpty
                                  ? DateTime.tryParse(birthdayController.text) ??
                                      DateTime.now()
                                  : DateTime.now(),
                            );

                            if (selectedDate != null) {
                              birthdayController.text =
                                  selectedDate.toIso8601String().split('T').first;
                            }
                          },
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please select birthday';
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<int>(
                          initialValue: selectedDepartmentId,
                          decoration: const InputDecoration(labelText: 'Department'),
                          items: departments
                              .map(
                                (LookupOption department) => DropdownMenuItem<int>(
                                  value: department.id,
                                  child: Text(department.name),
                                ),
                              )
                              .toList(),
                          onChanged: _isUpdating
                              ? null
                              : (int? value) {
                                  setDialogState(() {
                                    selectedDepartmentId = value;
                                    selectedPositionId = null;
                                    positionsFuture = value == null
                                        ? Future<List<LookupOption>>.value(<LookupOption>[])
                                        : _organizationService.getPositions(value);
                                  });
                                },
                          validator: (int? value) {
                            if (value == null) {
                              return 'Please select department';
                            }
                            return null;
                          },
                        ),
                        FutureBuilder<List<LookupOption>>(
                          future: positionsFuture,
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<List<LookupOption>> snapshot,
                          ) {
                            final List<LookupOption> positions =
                                snapshot.data ?? <LookupOption>[];
                            final bool positionsLoading =
                                snapshot.connectionState == ConnectionState.waiting;
                            final bool hasSelectedPosition = positions.any(
                              (LookupOption option) => option.id == selectedPositionId,
                            );

                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: DropdownButtonFormField<int>(
                                initialValue: hasSelectedPosition ? selectedPositionId : null,
                                decoration: InputDecoration(
                                  labelText: 'Position',
                                  suffixIcon: positionsLoading
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        )
                                      : null,
                                ),
                                items: positions
                                    .map(
                                      (LookupOption position) => DropdownMenuItem<int>(
                                        value: position.id,
                                        child: Text(position.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _isUpdating || selectedDepartmentId == null
                                    ? null
                                    : (int? value) {
                                        setDialogState(() {
                                          selectedPositionId = value;
                                        });
                                      },
                                validator: (int? value) {
                                  if (value == null) {
                                    return 'Please select position';
                                  }
                                  return null;
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: _isUpdating
                        ? null
                        : () {
                            navigator.pop();
                          },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _isUpdating
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            if (selectedDepartmentId == null || selectedPositionId == null) {
                              return;
                            }

                            setState(() {
                              _isUpdating = true;
                            });

                            try {
                              final UserProfile updated =
                                  await _profileService.updateProfile(
                                fullName: fullNameController.text.trim(),
                                birthday: birthdayController.text.trim(),
                                departmentId: selectedDepartmentId!,
                                positionId: selectedPositionId!,
                              );

                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                _profileFuture = Future<UserProfile>.value(updated);
                              });
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Profile updated')),
                              );
                            } on DioException catch (e) {
                              final String message = ApiService.buildErrorMessage(
                                e,
                                fallbackMessage: 'Failed to update profile',
                              );
                              messenger.showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isUpdating = false;
                                });
                              }
                            }
                          },
                    child: _isUpdating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      fullNameController.dispose();
      birthdayController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (BuildContext context, AsyncSnapshot<UserProfile> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorStateView(
              message: 'Failed to load profile',
              onRetry: () {
                setState(() {
                  _profileFuture = _profileService.getProfile();
                });
              },
            );
          }

          final UserProfile profile = snapshot.data!;

          return Consumer<AuthProvider>(
            builder: (BuildContext context, AuthProvider authProvider, Widget? _) {
              return ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _buildProfileHeader(profile),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (profile.isAdmin) ...<Widget>[
                          _buildAdminCard(profile),
                          AppSpacing.gapLg,
                        ],
                        _buildInfoCard(profile),
                        AppSpacing.gapLg,
                        _buildRadiusCard(profile),
                        AppSpacing.gapLg,
                        _buildMySightings(),
                        AppSpacing.gapLg,
                        OutlinedButton.icon(
                          onPressed: () => _showEditDialog(profile),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Profile'),
                        ),
                        AppSpacing.gapMd,
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerLight,
                            foregroundColor: AppColors.danger,
                          ),
                          onPressed: () async {
                            await authProvider.logout();

                            if (!context.mounted) {
                              return;
                            }

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
