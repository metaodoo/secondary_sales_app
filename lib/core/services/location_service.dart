import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'kinematic_location_bridge.dart';

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

  /// Captures a high-accuracy GPS fix by streaming satellite positions and
  /// sampling until an accurate reading is obtained (accuracy <= [desiredAccuracyInMeters])
  /// or until [timeLimit] elapses, returning the highest precision fix recorded.
  ///
  /// Fixes coarser than [maxAcceptableAccuracyInMeters] (e.g. 1-3 km cell towers)
  /// are rejected on timeout to prevent saving false locations.
  static Future<Position> getAccuratePosition({
    double desiredAccuracyInMeters = 25.0,
    double maxAcceptableAccuracyInMeters = 100.0,
    Duration timeLimit = const Duration(seconds: 12),
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

    Position? bestPosition;
    final completer = Completer<Position>();
    StreamSubscription<Position>? subscription;

    void updateBest(Position pos) {
      if (bestPosition == null || pos.accuracy < bestPosition!.accuracy) {
        bestPosition = pos;
      }
      // Once we reach target accuracy (e.g. <= 25m), resolve immediately!
      if (pos.accuracy <= desiredAccuracyInMeters && !completer.isCompleted) {
        completer.complete(pos);
      }
    }

    subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen(
      updateBest,
      onError: (_) {},
    );

    // Concurrently trigger a high-precision one-shot query to prime the provider
    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    ).then(updateBest).catchError((_) {});

    final timer = Timer(timeLimit, () {
      if (!completer.isCompleted) {
        if (bestPosition != null &&
            bestPosition!.accuracy > 0 &&
            bestPosition!.accuracy <= maxAcceptableAccuracyInMeters) {
          completer.complete(bestPosition);
        } else {
          final accDetail = bestPosition != null && bestPosition!.accuracy > 0
              ? ' (accuracy ±${bestPosition!.accuracy.round()}m is too coarse)'
              : '';
          completer.completeError(
            Exception(
              'Could not get an accurate GPS satellite fix$accDetail. '
              'Please ensure you have a clear view of the sky and try again.',
            ),
          );
        }
      }
    });

    try {
      final result = await completer.future;
      return result;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  /// Fast-converging GPS position resolver for check-in and attendance actions.
  /// 1. Re-uses fresh (< 25s old) cached position if already accurate (<= 30m) -> 0ms latency.
  /// 2. Otherwise runs a short precision burst (up to [burstTimeout]), returning as soon as
  ///    a fix with accuracy <= [desiredAccuracy] is established.
  /// 3. If timeout occurs, returns best fix recorded if accuracy <= [maxAcceptableAccuracy].
  ///    Rejects stale fixes (> 2 mins old).
  static Future<Position> resolveCheckInPosition({
    Position? cachedPosition,
    double desiredAccuracy = 25.0,
    double maxAcceptableAccuracy = 70.0,
    Duration burstTimeout = const Duration(seconds: 4),
  }) async {
    final now = DateTime.now();

    // 1. Instant Cache Re-use (0 ms latency) if fresh and sharp
    if (cachedPosition != null) {
      final ageSeconds = now.difference(cachedPosition.timestamp).inSeconds;
      if (ageSeconds <= 25 && cachedPosition.accuracy <= 30.0) {
        KinematicLocationBridge.instance.updateFix(cachedPosition);
        return cachedPosition;
      }
    }

    // 2. Kinematic Bridge Check: Re-use stationary / dead-reckoned fix if confidence >= 0.75
    final estimated = KinematicLocationBridge.instance.getEstimatedPosition(referenceTime: now);
    if (estimated != null && estimated.confidence >= 0.75 && estimated.accuracy <= desiredAccuracy) {
      return estimated.toPosition();
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('Location services are disabled. Please enable GPS and try again.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    // 3. Short precision burst
    final completer = Completer<Position>();
    Position? bestPosition = cachedPosition;
    StreamSubscription<Position>? subscription;

    void onFix(Position pos) {
      KinematicLocationBridge.instance.updateFix(pos);
      if (bestPosition == null || pos.accuracy <= bestPosition!.accuracy) {
        bestPosition = pos;
      }
      if (pos.accuracy <= desiredAccuracy && !completer.isCompleted) {
        completer.complete(pos);
      }
    }

    subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(onFix, onError: (_) {});

    // Concurrently trigger one-shot query to nudge the GPS chip
    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).then(onFix).catchError((_) {});

    final timer = Timer(burstTimeout, () {
      if (!completer.isCompleted) {
        if (bestPosition != null &&
            bestPosition!.accuracy > 0 &&
            bestPosition!.accuracy <= maxAcceptableAccuracy) {
          KinematicLocationBridge.instance.updateFix(bestPosition!);
          completer.complete(bestPosition!);
        } else {
          // Check kinematic fallback before throwing
          final fallbackEst = KinematicLocationBridge.instance.getEstimatedPosition();
          if (fallbackEst != null &&
              fallbackEst.confidence >= 0.5 &&
              fallbackEst.accuracy <= maxAcceptableAccuracy) {
            completer.complete(fallbackEst.toPosition());
            return;
          }

          final accMsg = bestPosition != null && bestPosition!.accuracy > 0
              ? ' (accuracy ±${bestPosition!.accuracy.round()}m is degraded)'
              : '';
          completer.completeError(
            Exception(
              'Weak GPS satellite signal$accMsg. '
              'Please step outside the canopy or move near an open area and try again.',
            ),
          );
        }
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }
}
