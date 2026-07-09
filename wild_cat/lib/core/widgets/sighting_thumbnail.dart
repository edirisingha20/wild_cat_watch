import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Consistent leopard-sighting image with graceful loading/placeholder/error
/// states. Used in list cards and thumbnails throughout the app.
class SightingThumbnail extends StatelessWidget {
  const SightingThumbnail({
    super.key,
    required this.imageUrl,
    this.width = 64,
    this.height = 64,
    this.borderRadius = 12,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, Widget child, ImageChunkEvent? progress) {
                  if (progress == null) return child;
                  return _placeholder(loading: true);
                },
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: AppColors.oliveLight,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.pets, color: AppColors.forestGreen, size: 26),
    );
  }
}
