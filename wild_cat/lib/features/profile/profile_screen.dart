import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/organization_service.dart';
import '../../services/profile_service.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
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
  late Future<UserProfile> _profileFuture;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.getProfile();
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
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
