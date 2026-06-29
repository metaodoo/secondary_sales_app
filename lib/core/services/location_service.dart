import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Request permission and get the current position
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('Location services are disabled. Please enable GPS in settings and try again.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // If it times out or fails, try to get last known position
      try {
        final lastKnown = await Geolocator.getLastKnownPosition().timeout(
          const Duration(seconds: 3),
        );
        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {
        // Ignore last known position timeout
      }
      throw Exception(
        'Failed to get current location (Timed out). Please check location settings.',
      );
    }
  }
}
