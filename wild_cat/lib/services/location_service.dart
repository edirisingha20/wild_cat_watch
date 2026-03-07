import 'package:geolocator/geolocator.dart';

class LocationServiceException implements Exception {
  LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<Position> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationServiceException('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException('Location permission denied forever');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}
