import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a kinematically estimated position during GPS cut-off or time-gap periods.
class EstimatedPosition {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;
  final double confidence; // 0.0 to 1.0
  final bool isStationary;

  const EstimatedPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.timestamp,
    required this.confidence,
    required this.isStationary,
  });

  /// Converts to standard Geolocator [Position] object for downstream consumers.
  Position toPosition() {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: 0.0,
      heading: heading,
      speed: speed,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}

/// Google Maps-inspired Kinematic Location Bridge.
///
/// Bridges the latency gap and duty-cycle cut-off periods between GPS fixes using:
/// 1. Dead Reckoning: Kinematic state forward projection based on speed and heading.
/// 2. Stationary Invariance: When stationary (< 0.8 m/s), coordinates remain 100% valid
///    even under tin-roof canopies or indoor shop counters.
/// 3. Exponential Temporal Confidence Decay: Graceful decay replacing binary timeouts.
/// 4. Shared Cross-Isolate Memory: Seamlessly shares latest fixes between background
///    and foreground without redundant GNSS wakeups.
class KinematicLocationBridge {
  static final KinematicLocationBridge _instance = KinematicLocationBridge._internal();
  static KinematicLocationBridge get instance => _instance;

  KinematicLocationBridge._internal() {
    _hydrateFromStorage();
  }

  Position? _lastFix;
  DateTime? _lastTimestamp;
  double _lastSpeed = 0.0;
  double _lastHeading = 0.0;

  static const String _kPrefBridgeLat = 'kinematic_bridge_lat';
  static const String _kPrefBridgeLng = 'kinematic_bridge_lng';
  static const String _kPrefBridgeAcc = 'kinematic_bridge_acc';
  static const String _kPrefBridgeTime = 'kinematic_bridge_time';
  static const String _kPrefBridgeSpeed = 'kinematic_bridge_speed';
  static const String _kPrefBridgeHeading = 'kinematic_bridge_heading';

  /// Tau constant for exponential confidence decay: 45 seconds for field sales.
  static const double _kDecayTauSeconds = 45.0;

  Position? get latestRawFix => _lastFix;

  /// Updates the bridge with a newly acquired GPS fix.
  void updateFix(Position fix) {
    // Accuracy gating: reject degraded multipath (> 75m) if we have a sharp fix (< 30m) within 90s
    if (_lastFix != null && _lastFix!.accuracy <= 30.0) {
      final now = DateTime.now();
      final age = now.difference(_lastFix!.timestamp).inSeconds;
      if (age < 90 && fix.accuracy > 75.0) {
        return; // Reject coarse spike
      }
    }

    _lastFix = fix;
    _lastTimestamp = DateTime.now();
    _lastSpeed = fix.speed >= 0 ? fix.speed : 0.0;
    _lastHeading = fix.heading >= 0 ? fix.heading : 0.0;

    _persistToStorage(fix);
  }

  /// Calculates the current estimated position by kinematically extrapolating
  /// across the time gap (Δt) since the last fix.
  EstimatedPosition? getEstimatedPosition({DateTime? referenceTime}) {
    if (_lastFix == null) return null;

    final now = referenceTime ?? DateTime.now();
    final fixTime = _lastTimestamp ?? _lastFix!.timestamp;
    final deltaSeconds = (now.millisecondsSinceEpoch - fixTime.millisecondsSinceEpoch) / 1000.0;

    if (deltaSeconds < 0) {
      // Clock skew safety
      return _createEstimate(_lastFix!.latitude, _lastFix!.longitude, _lastFix!.accuracy, 1.0, true, now);
    }

    // Hard boundary: older than 3 minutes cannot be reliably dead-reckoned
    if (deltaSeconds > 180.0) {
      return null;
    }

    // Exponential confidence decay: C = exp(-Δt / τ)
    final confidence = math.exp(-deltaSeconds / _kDecayTauSeconds);

    final isStationary = _lastSpeed < 0.8; // Under walking speed (0.8 m/s ~ 2.8 km/h)

    if (isStationary) {
      // STATIONARY CASE: Rep is standing at the store counter or under canopy.
      // Position is invariant; uncertainty expands slightly due to clock drift (0.1m per sec)
      final expandedAccuracy = _lastFix!.accuracy + (deltaSeconds * 0.1);
      return _createEstimate(
        _lastFix!.latitude,
        _lastFix!.longitude,
        expandedAccuracy,
        confidence,
        true,
        now,
      );
    } else {
      // IN-MOTION CASE: Rep is walking or riding bike.
      // Extrapolate forward along velocity vector: Δd = v * Δt
      final displacementMeters = _lastSpeed * deltaSeconds;
      final radHeading = _lastHeading * (math.pi / 180.0);

      final deltaLatMeters = displacementMeters * math.cos(radHeading);
      final deltaLngMeters = displacementMeters * math.sin(radHeading);

      // 1 degree latitude ~ 111,320 meters
      final deltaLatDegrees = deltaLatMeters / 111320.0;
      final avgLatRad = _lastFix!.latitude * (math.pi / 180.0);
      final metersPerLngDegree = 111320.0 * math.cos(avgLatRad);
      final deltaLngDegrees = metersPerLngDegree > 0 ? (deltaLngMeters / metersPerLngDegree) : 0.0;

      final projectedLat = _lastFix!.latitude + deltaLatDegrees;
      final projectedLng = _lastFix!.longitude + deltaLngDegrees;

      // In-motion uncertainty grows at 0.2m per meter traveled
      final expandedAccuracy = _lastFix!.accuracy + (displacementMeters * 0.2);

      return _createEstimate(
        projectedLat,
        projectedLng,
        expandedAccuracy,
        confidence,
        false,
        now,
      );
    }
  }

  EstimatedPosition _createEstimate(
    double lat,
    double lng,
    double acc,
    double conf,
    bool stationary,
    DateTime now,
  ) {
    return EstimatedPosition(
      latitude: lat,
      longitude: lng,
      accuracy: acc,
      speed: _lastSpeed,
      heading: _lastHeading,
      timestamp: now,
      confidence: conf,
      isStationary: stationary,
    );
  }

  Future<void> _persistToStorage(Position fix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPrefBridgeLat, fix.latitude);
      await prefs.setDouble(_kPrefBridgeLng, fix.longitude);
      await prefs.setDouble(_kPrefBridgeAcc, fix.accuracy);
      await prefs.setDouble(_kPrefBridgeSpeed, fix.speed);
      await prefs.setDouble(_kPrefBridgeHeading, fix.heading);
      await prefs.setInt(_kPrefBridgeTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Manually syncs latest cross-isolate state from SharedPreferences.
  Future<void> syncFromStorage() => _hydrateFromStorage();

  Future<void> _hydrateFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final lat = prefs.getDouble(_kPrefBridgeLat);
      final lng = prefs.getDouble(_kPrefBridgeLng);
      final acc = prefs.getDouble(_kPrefBridgeAcc);
      final timeMs = prefs.getInt(_kPrefBridgeTime);
      final speed = prefs.getDouble(_kPrefBridgeSpeed) ?? 0.0;
      final heading = prefs.getDouble(_kPrefBridgeHeading) ?? 0.0;

      if (lat != null && lng != null && acc != null && timeMs != null) {
        final fixTime = DateTime.fromMillisecondsSinceEpoch(timeMs);
        final age = DateTime.now().difference(fixTime).inMinutes;
        if (age < 15) {
          _lastFix = Position(
            latitude: lat,
            longitude: lng,
            timestamp: fixTime,
            accuracy: acc,
            altitude: 0.0,
            heading: heading,
            speed: speed,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
          _lastTimestamp = fixTime;
          _lastSpeed = speed;
          _lastHeading = heading;
        }
      }
    } catch (_) {}
  }
}

