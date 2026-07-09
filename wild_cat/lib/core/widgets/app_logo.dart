import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The Leopard Sightings logo, rendered from the bundled asset.
///
/// Rounded to match the launcher icon so it reads as the app's brand mark
/// wherever it appears (splash, login header).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.borderRadius});

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.xl),
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
