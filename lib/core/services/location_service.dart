import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Request permission and get the current device position.
  ///
  /// For geofenced actions (e.g. outlet check-in) pass [requireFresh] = true.
  /// In that mode the method never falls back to [Geolocator.getLastKnownPosition],
  /// because a stale cached fix from a previous location can silently pass a
  /// server-side geofence check and produce a phantom check-in. If a fresh fix
  /// cannot be obtained within [timeLimit] it throws, so the caller can ask the
  /// user to retry instead of proceeding with old coordinates.
  ///
  /// [maxAccuracyMeters], when set, rejects a fix whose reported horizontal
  /// accuracy is worse (larger) than the given value.
  static Future<Position> getCurrentPosition({
    bool requireFresh = false,
    Duration? timeLimit,
    double? maxAccuracyMeters,
  }) async {
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
    final effectiveTimeLimit = timeLimit ?? const Duration(seconds: 5);

    Position? fresh;
    try {
      fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(effectiveTimeLimit);
    } catch (_) {
      fresh = null;
    }

    if (fresh != null) {
      // Reject a fresh but low-quality fix that could land inside a geofence
      // by chance. accuracy <= 0 means "unknown", so we don't gate on it.
      if (maxAccuracyMeters != null &&
          fresh.accuracy > 0 &&
          fresh.accuracy > maxAccuracyMeters) {
        throw Exception(
          'GPS signal is too weak (accuracy ±${fresh.accuracy.toStringAsFixed(0)} m). '
          'Please move to an open area and try again.',
        );
      }
      return fresh;
    }

    // No fresh fix could be obtained within the time limit.
    if (requireFresh) {
      // Never authorise a geofenced action with a stale cached position.
      throw Exception(
        'Could not get an accurate GPS fix. Please ensure you have a clear '
        'view of the sky and try again.',
      );
    }

    // Legacy behaviour for non-geofenced callers: fall back to the last known
    // position rather than failing outright.
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
