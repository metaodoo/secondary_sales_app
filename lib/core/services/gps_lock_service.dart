import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'kinematic_location_bridge.dart';

enum GpsLockStatus {
  acquiring, // Searching for GNSS satellites
  locked,    // Sharp satellite fix established (accuracy <= 25m)
  weak,      // Fix available but degraded (accuracy > 45m or obstructed)
  disabled,  // Device location service turned off
  denied,    // Location permission denied
}

class GpsLockState {
  final GpsLockStatus status;
  final double? accuracy;
  final Position? position;
  final String? message;

  const GpsLockState({
    required this.status,
    this.accuracy,
    this.position,
    this.message,
  });

  bool get isLocked => status == GpsLockStatus.locked;
  bool get isUsable => (status == GpsLockStatus.locked || status == GpsLockStatus.weak) && position != null;
}

/// Lightweight, hardware-conscious GPS lock tracker designed for low-budget
/// phones. Only runs on GPS-critical screens and cancels immediately when
/// the screen is closed or paused.
class GpsLockService {
  final ValueNotifier<GpsLockState> stateNotifier = ValueNotifier<GpsLockState>(
    const GpsLockState(
      status: GpsLockStatus.acquiring,
      message: 'Acquiring GPS satellite lock...',
    ),
  );

  StreamSubscription<Position>? _subscription;
  Timer? _lockTimeoutTimer;
  Position? _bestPosition;
  bool _isDisposed = false;

  GpsLockState get state => stateNotifier.value;
  Position? get currentPosition => _bestPosition ?? stateNotifier.value.position;

  /// Starts ambient GNSS lock monitoring with low battery drain.
  Future<void> startTracking({
    double targetAccuracy = 25.0,
    double weakThreshold = 45.0,
    Duration lockTimeout = const Duration(seconds: 6),
    void Function(Position position)? onPositionUpdate,
  }) async {
    _cancelTracking();
    if (_isDisposed) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _updateState(
        GpsLockStatus.disabled,
        message: 'Device location is turned off. Tap to enable.',
      );
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _updateState(
        GpsLockStatus.denied,
        message: 'Location permission required for route visits.',
      );
      return;
    }

    final initialEstimate = KinematicLocationBridge.instance.getEstimatedPosition();
    if (initialEstimate != null && initialEstimate.confidence >= 0.7 && initialEstimate.accuracy <= targetAccuracy) {
      _bestPosition = initialEstimate.toPosition();
      _updateState(
        GpsLockStatus.locked,
        accuracy: initialEstimate.accuracy,
        position: _bestPosition,
        message: 'GPS Satellite Lock Ready (±${initialEstimate.accuracy.round()}m)',
      );
    } else {
      _updateState(
        GpsLockStatus.acquiring,
        message: 'Acquiring GPS satellite lock...',
      );
    }

    // Timeout timer: if after lockTimeout seconds we haven't reached targetAccuracy,
    // transition to 'weak' non-intrusive warning so the rep knows signal is degraded.
    _lockTimeoutTimer = Timer(lockTimeout, () {
      if (_isDisposed) return;
      if (stateNotifier.value.status == GpsLockStatus.acquiring) {
        if (_bestPosition != null) {
          final acc = _bestPosition!.accuracy;
          _updateState(
            acc <= targetAccuracy ? GpsLockStatus.locked : GpsLockStatus.weak,
            accuracy: acc,
            position: _bestPosition,
            message: acc <= targetAccuracy
                ? 'GPS Satellite Lock Ready (±${acc.round()}m)'
                : 'Weak GPS reception (±${acc.round()}m). Step outside the canopy.',
          );
        } else {
          _updateState(
            GpsLockStatus.weak,
            message: 'Waiting for GPS satellites. Ensure clear view of sky.',
          );
        }
      }
    });

    try {
      _subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // HAL discards sub-5m jitter while standing still
        ),
      ).listen(
        (Position pos) {
          if (_isDisposed) return;
          KinematicLocationBridge.instance.updateFix(pos);
          if (_bestPosition == null || pos.accuracy <= _bestPosition!.accuracy) {
            _bestPosition = pos;
          } else if (pos.accuracy < 35.0) {
            _bestPosition = pos;
          }

          onPositionUpdate?.call(pos);

          if (pos.accuracy <= targetAccuracy) {
            _updateState(
              GpsLockStatus.locked,
              accuracy: pos.accuracy,
              position: pos,
              message: 'GPS Satellite Lock Ready (±${pos.accuracy.round()}m)',
            );
          } else if (pos.accuracy <= weakThreshold) {
            _updateState(
              GpsLockStatus.locked, // usable
              accuracy: pos.accuracy,
              position: pos,
              message: 'GPS Ready (±${pos.accuracy.round()}m)',
            );
          } else {
            // Still coarse (e.g. cell tower / indoor)
            if (stateNotifier.value.status != GpsLockStatus.acquiring) {
              _updateState(
                GpsLockStatus.weak,
                accuracy: pos.accuracy,
                position: pos,
                message: 'Weak GPS reception (±${pos.accuracy.round()}m). Step outside canopy.',
              );
            }
          }
        },
        onError: (e) {
          debugPrint('GpsLockService error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start GpsLockService: $e');
    }
  }

  void _updateState(
    GpsLockStatus status, {
    double? accuracy,
    Position? position,
    String? message,
  }) {
    if (_isDisposed) return;
    stateNotifier.value = GpsLockState(
      status: status,
      accuracy: accuracy,
      position: position,
      message: message,
    );
  }

  void _cancelTracking() {
    _lockTimeoutTimer?.cancel();
    _lockTimeoutTimer = null;
    _subscription?.cancel();
    _subscription = null;
  }

  void pause() {
    _cancelTracking();
  }

  void resume({void Function(Position position)? onPositionUpdate}) {
    startTracking(onPositionUpdate: onPositionUpdate);
  }

  void dispose() {
    _isDisposed = true;
    _cancelTracking();
    stateNotifier.dispose();
  }
}
