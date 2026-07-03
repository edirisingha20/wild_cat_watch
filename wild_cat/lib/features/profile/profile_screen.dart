import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/organization_service.dart';
import '../../services/profile_service.dart';
import '../../services/sightings_service.dart';
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

  Widget _buildRadiusCard(UserProfile profile) {
    final double radius = _radiusKm ??= profile.sightingRadiusKm;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.my_location, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Alert radius',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${radius.round()} km'),
              ],
            ),
            const Text(
              'You only see sightings and receive alerts within this distance.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
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
        const Text(
          'My Reported Sightings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Alert>>(
          future: _mySightingsFuture,
          builder: (BuildContext context, AsyncSnapshot<List<Alert>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Text('Failed to load your sightings.');
            }
            final List<Alert> sightings = snapshot.data ?? <Alert>[];
            if (sightings.isEmpty) {
              return const Text("You haven't reported any sightings yet.");
            }
            return Column(
              children: sightings.map(_sightingTile).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _sightingTile(Alert alert) {
    final bool verified = alert.isVerified;
    final String date = alert.createdAt.toLocal().toString().split('.').first;
    return Card(
      child: ListTile(
        leading: alert.image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  alert.image!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
                ),
              )
            : const Icon(Icons.pets),
        title: Text(alert.locationName),
        subtitle: Text(date),
        trailing: Chip(
          label: Text(verified ? 'Verified' : 'Pending'),
          backgroundColor:
              verified ? Colors.green.shade100 : Colors.orange.shade100,
          visualDensity: VisualDensity.compact,
        ),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Failed to load profile'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _profileFuture = _profileService.getProfile();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final UserProfile profile = snapshot.data!;

          return Consumer<AuthProvider>(
            builder: (BuildContext context, AuthProvider authProvider, Widget? _) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text('Full Name: ${profile.fullName}'),
                  const SizedBox(height: 8),
                  Text('Username: ${profile.username}'),
                  const SizedBox(height: 8),
                  Text('Email: ${profile.email}'),
                  const SizedBox(height: 8),
                  Text('Birthday: ${profile.birthday ?? '-'}'),
                  const SizedBox(height: 8),
                  Text('Department: ${profile.department?.name ?? '-'}'),
                  const SizedBox(height: 8),
                  Text('Position: ${profile.position?.name ?? '-'}'),
                  const SizedBox(height: 16),
                  _buildRadiusCard(profile),
                  const SizedBox(height: 16),
                  _buildMySightings(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showEditDialog(profile),
                    child: const Text('Edit Profile'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
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
                    child: const Text('Logout'),
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
