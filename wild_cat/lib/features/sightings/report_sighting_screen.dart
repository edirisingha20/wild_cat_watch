import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/navigation/main_navigation_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/sightings_service.dart';

class ReportSightingScreen extends StatefulWidget {
  const ReportSightingScreen({super.key});
  @override
  State<ReportSightingScreen> createState() => _ReportSightingScreenState();
}

class _ReportSightingScreenState extends State<ReportSightingScreen> {
  final SightingsService _sightingsService = SightingsService();
  final LocationService _locationService = LocationService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  File? _selectedImage;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    // Auto-capture location so the officer sees an up-to-date GPS fix without
    // an extra tap. They can still refresh it manually below.
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureLocation());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (image == null) {
        return;
      }
      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (_) {
      _showSnackBar('Failed to pick image');
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } on LocationServiceException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Failed to fetch location');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      _showSnackBar('Please add a photo of the sighting');
      return;
    }

    if (_latitude == null || _longitude == null) {
      _showSnackBar('Location is not available');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _sightingsService.reportSighting(
        description: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        locationName: _buildLocationName(_latitude!, _longitude!),
        imageFile: _selectedImage!,
      );

      if (!mounted) {
        return;
      }

      _showSnackBar('Sighting reported successfully', success: true);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const MainNavigationScreen(initialIndex: 0),
          ),
        );
      }
    } on DioException catch (e) {
      _showSnackBar(
        ApiService.buildErrorMessage(
          e,
          fallbackMessage: 'Failed to submit report',
        ),
      );
    } catch (_) {
      _showSnackBar('Failed to submit report');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.success : null,
        content: Text(message),
      ),
    );
  }

  String _buildLocationName(double latitude, double longitude) {
    return 'Lat ${latitude.toStringAsFixed(5)}, Lng ${longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLocation = _latitude != null && _longitude != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Report Sighting')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildImageCard(),
                  AppSpacing.gapLg,
                  _buildLocationCard(hasLocation),
                  AppSpacing.gapLg,
                  _buildDescriptionCard(),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send_outlined),
                    label: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Submit Report'),
                  ),
                  AppSpacing.gapSm,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Image upload card ──────────────────────────────────────────────────────

  Widget _buildImageCard() {
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardHeader(Icons.photo_camera_outlined, 'Sighting Photo'),
            AppSpacing.gapMd,
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: _selectedImage == null
                  ? DottedPlaceholder(
                      onTap: _isSubmitting
                          ? null
                          : () => _pickImage(ImageSource.camera),
                    )
                  : Stack(
                      children: <Widget>[
                        Image.file(
                          _selectedImage!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Colors.white),
                              onPressed: _isSubmitting
                                  ? null
                                  : () =>
                                      setState(() => _selectedImage = null),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            AppSpacing.gapMd,
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            if (_selectedImage == null) ...<Widget>[
              AppSpacing.gapSm,
              Text(
                'A clear photo helps officers verify the sighting.',
                style:
                    text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── GPS status card ────────────────────────────────────────────────────────

  Widget _buildLocationCard(bool hasLocation) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color statusColor = _isFetchingLocation
        ? AppColors.amber
        : (hasLocation ? AppColors.success : AppColors.danger);
    final String statusLabel = _isFetchingLocation
        ? 'Locating…'
        : (hasLocation ? 'Location captured' : 'Location unavailable');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _cardHeader(Icons.my_location_outlined, 'GPS Location'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_isFetchingLocation)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        )
                      else
                        Icon(
                          hasLocation ? Icons.check_circle : Icons.error_outline,
                          size: 14,
                          color: statusColor,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: text.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.place_outlined,
                      size: 18, color: AppColors.forestGreen),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      hasLocation
                          ? '${_latitude!.toStringAsFixed(5)},  ${_longitude!.toStringAsFixed(5)}'
                          : 'Coordinates will appear here',
                      style: text.bodyMedium?.copyWith(
                        color: hasLocation
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapMd,
            OutlinedButton.icon(
              onPressed:
                  _isSubmitting || _isFetchingLocation ? null : _captureLocation,
              icon: const Icon(Icons.refresh),
              label: Text(hasLocation ? 'Update Location' : 'Get Location'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Description card ───────────────────────────────────────────────────────

  Widget _buildDescriptionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardHeader(Icons.description_outlined, 'Description'),
            AppSpacing.gapMd,
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Describe the sighting — behaviour, surroundings, any risk…',
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.forestGreen),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Dotted image placeholder ──────────────────────────────────────────────────

class DottedPlaceholder extends StatelessWidget {
  const DottedPlaceholder({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.oliveLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.forestGreenLight,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.add_a_photo_outlined,
                size: 40, color: AppColors.forestGreen),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap to add a photo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
