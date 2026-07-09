import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A circular avatar that shows the user's initials over the brand green.
/// Used in the profile header and user lists.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.radius = 32});

  final String name;
  final double radius;

  String get _initials {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.forestGreen,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
