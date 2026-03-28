import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
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
    final TextEditingController designationController =
        TextEditingController(text: profile.designation);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    TextField(
                      controller: birthdayController,
                      decoration: const InputDecoration(
                        labelText: 'Birthday (YYYY-MM-DD)',
                      ),
                    ),
                    TextField(
                      controller: designationController,
                      decoration: const InputDecoration(labelText: 'Designation'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : () async {
                          setState(() {
                            _isUpdating = true;
                          });
                          setDialogState(() {});

                          try {
                            final UserProfile updated = await _profileService.updateProfile(
                              fullName: fullNameController.text.trim(),
                              birthday: birthdayController.text.trim().isEmpty
                                  ? null
                                  : birthdayController.text.trim(),
                              designation: designationController.text.trim(),
                            );

                            if (!mounted) {
                              return;
                            }

                            setState(() {
                              _profileFuture = Future<UserProfile>.value(updated);
                            });
                            Navigator.of(this.context, rootNavigator: true).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Profile updated')),
                            );
                          } on DioException catch (e) {
                            final String message = ApiService.buildErrorMessage(
                              e,
                              fallbackMessage: 'Failed to update profile',
                            );
                            ScaffoldMessenger.of(this.context).showSnackBar(
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
                    Text('Designation: ${profile.designation}'),
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
