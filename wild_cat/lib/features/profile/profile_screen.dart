import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<AuthProvider>(
        builder: (BuildContext context, AuthProvider authProvider, Widget? _) {
          final String fullName =
              authProvider.currentUser?.fullName ?? 'Wild Cat User';
          final String email =
              authProvider.currentUser?.email ?? 'user@example.com';
          final String designation =
              authProvider.currentUser?.designation ?? 'Community Member';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Full Name: $fullName'),
                const SizedBox(height: 8),
                Text('Email: $email'),
                const SizedBox(height: 8),
                Text('Designation: $designation'),
                const SizedBox(height: 16),
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
      ),
    );
  }
}
