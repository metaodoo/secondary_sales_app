import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Request permission and get the current device position.
  ///
  /// For geofenced actions (e.g. outlet check-in) pass [requireFresh] = true.
  /// In that mode the method never falls back to
  /// [Geolocator.getLastKnownPosition], because a stale cached fix from a
  /// previous outlet can both fail a geofence you are standing inside and pass
  /// one you are nowhere near. If no fresh fix arrives within [timeLimit] it
  /// throws, so the caller can ask the user to retry.
  ///
  /// A fresh but low-accuracy fix is still returned. The server owns the
  /// distance decision via `ss_attendance_radius`; blocking here on accuracy
  /// only stops legitimate check-ins indoors.
  static Future<Position> getCurrentPosition({
    bool requireFresh = false,
    Duration? timeLimit,
  }) async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception(
        'Location services are disabled. Please enable GPS in settings and try again.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, cannot request permissions.',
      );
    }

    final effectiveTimeLimit = timeLimit ?? const Duration(seconds: 15);

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(effectiveTimeLimit);
    } catch (_) {
      // Fall through to the cached position, unless the caller forbids it.
    }

    if (requireFresh) {
      throw Exception(
        'Could not get a GPS fix. Please ensure you have a clear view of the '
        'sky and try again.',
      );
    }

    // Legacy behaviour for non-geofenced callers.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 3),
      );
      if (lastKnown != null) {
        return lastKnown;
      }
    } catch (_) {
      // Ignore last known position timeout.
    }

    throw Exception(
      'Could not retrieve GPS location. Please check device location settings and try again.',
    );
  }
}
