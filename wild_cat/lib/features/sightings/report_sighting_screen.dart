import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/navigation/main_navigation_screen.dart';
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      _showSnackBar('Please select an image');
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

      _showSnackBar('Sighting report submitted');
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
      final dynamic data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final String message = data['detail']?.toString() ??
            data['error']?.toString() ??
            'Failed to submit report';
        _showSnackBar(message);
      } else {
        _showSnackBar('Network or server error while submitting report');
      }
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildLocationName(double latitude, double longitude) {
    return 'Lat ${latitude.toStringAsFixed(5)}, Lng ${longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Sighting')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: double.infinity,
                height: 220,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: _selectedImage == null
                    ? const Text('No image selected')
                    : Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    child: const Text('Capture Image'),
                  ),
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    child: const Text('Pick From Gallery'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _latitude == null || _longitude == null
                          ? 'Location: Not captured'
                          : 'Location: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed:
                        _isSubmitting || _isFetchingLocation ? null : _captureLocation,
                    child: _isFetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Get Location'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
