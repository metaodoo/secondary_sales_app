import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/services/location_db_helper.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/api/auth_service.dart';

// SharedPreferences keys shared between the UI isolate (writer) and the
// background isolate (reader). Top-level so both can reference the same string.
const String _kPrefActive = 'location_tracking_active';
const String _kPrefInterval = 'location_tracking_interval';
const String _kPrefDistance = 'location_tracking_distance';
const String _kPrefSyncInterval = 'location_tracking_sync_interval';
const String _kPrefType = 'location_tracking_type';
const String _kPrefPermissionsRequested = 'location_permissions_requested';
const String _kPrefLastFlushAt = 'location_tracking_last_flush_at';
const String _kPrefNextSyncAfter = 'location_tracking_next_sync_after';
const String _kPrefSyncFailureCount = 'location_tracking_sync_failure_count';
const String _kPrefFlushLockAt = 'location_tracking_flush_lock_at';
const String _kPrefTokenRefreshAttemptAt =
    'location_tracking_token_refresh_attempt_at';
const int _kDefaultSyncIntervalSeconds = 3600;
const int _kMinimumSyncIntervalSeconds = 300;
const Duration _kFlushLockTtl = Duration(seconds: 90);
const Duration _kTokenRefreshCooldown = Duration(minutes: 5);

/// Drives background GPS logging while an employee is checked in.
///
/// Tracking is bound to attendance state, not the UI. The work runs inside a
/// foreground service (an Android persistent notification) hosted in its own
/// Dart isolate, so it keeps logging when the app is backgrounded, the screen
/// is locked, the user switches apps, and after the app is swiped from recents
/// (the service is sticky, and [resumeIfActive] restarts it on next launch).
///
/// Coordinates are not uploaded one-by-one. They are captured on a time cadence,
/// filtered by a distance threshold (a stationary rep produces almost nothing),
/// written to a local SQLite buffer ([LocationDbHelper]), and flushed to Odoo in
/// batches every [_kPrefSyncInterval] seconds — plus one final forced flush on
/// checkout so the last leg of the route isn't stranded until the next shift.
///
/// The background isolate cannot see the UI's [ApiService.instance] state, so
/// it re-primes credentials from [SharedPreferences] (written by AuthProvider)
/// and reuses the existing [LocationApi.syncEmployeeLocations] endpoint.
///
/// The `flutter_background_service` plugin only implements Android/iOS. On
/// desktop (e.g. Linux) and web every method here is a safe no-op so that
/// calling them from `main()` / the attendance flow never crashes the app.
class LocationTrackingService {
  LocationTrackingService._();

  static const int _notificationId = 913;

  static final StreamController<List<Map<String, dynamic>>> _autoCheckOutController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  /// Stream of auto-checked-out visits detected during location sync flushes.
  static Stream<List<Map<String, dynamic>>> get onAutoCheckOut =>
      _autoCheckOutController.stream;

  /// Whether the background service is supported on the current platform.
  /// Uses [defaultTargetPlatform] (not `dart:io`) so this compiles for web too.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Registers the background service. Call once from `main()` after
  /// [AppConstants.initialize]. Does not start tracking (`autoStart: false`).
  static Future<void> configure() async {
    if (!_supported) return;
    try {
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false,
          autoStartOnBoot: false,
          isForegroundMode: true,
          initialNotificationTitle: 'Attendance active',
          initialNotificationContent: 'Preparing location tracking…',
          foregroundServiceNotificationId: _notificationId,
          foregroundServiceTypes: const [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      );

      service.on('autoCheckOutVisits').listen((event) {
        final visitsRaw = event?['visits'];
        if (visitsRaw is List) {
          final visits = visitsRaw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          if (visits.isNotEmpty) {
            _autoCheckOutController.add(visits);
          }
        }
      });
    } catch (e) {
      // Never let service setup block app startup.
      if (kDebugMode) {
        debugPrint('LocationTrackingService.configure failed: $e');
      }
    }
  }

  /// Whether foreground location is already granted -- the minimum to track.
  ///
  /// Checking is silent; only [requestPermissionsOnce] ever shows a prompt.
  static Future<bool> hasForegroundLocation() async {
    if (!_supported) return false;
    try {
      return await Permission.location.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Whether the one-time permission onboarding has already run.
  static Future<bool> hasRequestedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrefPermissionsRequested) ?? false;
  }

  /// Requests every permission the tracking service wants -- **once, ever**.
  ///
  /// "Allow all the time" and the battery-optimization exemption are optional:
  /// tracking still works without them, just less reliably once the app is
  /// backgrounded. They are therefore asked for exactly once and never again.
  /// Re-asking is not merely annoying -- on Android 11+ `locationAlways` cannot
  /// be granted from a dialog, so the plugin sends the user to the Settings app.
  /// Doing that on every check-in is what this replaces.
  ///
  /// Safe to call on every launch: it returns immediately once the flag is set.
  static Future<bool> requestPermissionsOnce({bool force = false}) async {
    if (!_supported) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(_kPrefPermissionsRequested) ?? false)) {
      return Permission.location.isGranted;
    }

    try {
      // Mark first: a user who dismisses the OS dialog by backgrounding the app
      // must not be asked again on the next launch.
      await prefs.setBool(_kPrefPermissionsRequested, true);

      final whenInUse = await Permission.location.request();
      if (!whenInUse.isGranted) return false;

      if (!await Permission.locationAlways.isGranted) {
        await Permission.locationAlways.request();
      }
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationTrackingService.requestPermissionsOnce failed: $e');
      }
      return false;
    }
  }


  /// Marks tracking active and (re)starts the service with the given config.
  /// If already running, pushes the config to the live isolate instead.
  ///
  /// * [intervalSeconds]     — GPS sampling cadence (the timer period).
  /// * [distanceMeters]      — minimum move from the last stored point to buffer
  ///                           a new one. Ignored when [trackingType] == 'time'.
  /// * [syncIntervalSeconds] — how often the buffer is flushed to the server.
  /// * [trackingType]        — 'time' | 'distance' | 'both'.
  static Future<void> start({
    required int intervalSeconds,
    required int distanceMeters,
    required int syncIntervalSeconds,
    required String trackingType,
  }) async {
    if (!_supported) return;
    try {
      final normalizedSyncInterval = _normalizeSyncInterval(
        syncIntervalSeconds,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefActive, true);
      await prefs.setInt(_kPrefInterval, intervalSeconds);
      await prefs.setInt(_kPrefDistance, distanceMeters);
      await prefs.setInt(_kPrefSyncInterval, normalizedSyncInterval);
      await prefs.setString(_kPrefType, trackingType);

      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('updateConfig', {
          'interval': intervalSeconds,
          'distance': distanceMeters,
          'syncInterval': normalizedSyncInterval,
          'type': trackingType,
        });
      } else {
        await service.startService();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationTrackingService.start failed: $e');
      }
    }
  }

  /// Marks tracking inactive, forces a final flush of the buffer, then stops the
  /// service. The flush is awaited (up to a timeout) rather than fire-and-forget
  /// so the last coordinates reach the server before the isolate is torn down;
  /// on failure the buffer persists in SQLite and syncs on the next shift.
  static Future<void> stop() async {
    if (!_supported) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        await _finalFlushAndStop(service);
      }
      // Set inactive after the flush so a concurrent sampling tick doesn't
      // self-stop the isolate mid-upload (it self-stops when this flag is false).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefActive, false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationTrackingService.stop failed: $e');
      }
    }
  }

  /// Asks the isolate to flush now, waits for its `syncDone` acknowledgement
  /// (bounded), then tells it to stop. If the ack never arrives (offline / slow
  /// upload) we stop anyway — the buffer is durable and retries next shift.
  static Future<void> _finalFlushAndStop(
    FlutterBackgroundService service,
  ) async {
    try {
      final done = service
          .on('syncDone')
          .first
          .timeout(const Duration(seconds: 12));
      service.invoke('forceSync');
      await done;
    } catch (_) {
      // Timed out or errored — buffered rows remain for the next shift.
    } finally {
      service.invoke('stopService');
    }
  }

  /// Restarts the service on app launch if tracking was active but the process
  /// (and its service) had been killed — the "cleared from recents, reopened"
  /// recovery path.
  static Future<void> resumeIfActive() async {
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPrefActive) != true) return;

      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocationTrackingService.resumeIfActive failed: $e');
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Background isolate entrypoint (runs in the foreground service's own isolate).
// ---------------------------------------------------------------------------

// In-isolate state. Lives only as long as the isolate; reset on (re)start.
// The distance filter compares each fix against the last *stored* point, kept
// in memory so it survives flushing the SQLite buffer.
double? _lastStoredLat;
double? _lastStoredLng;
DateTime? _lastFlushAt;
bool _flushInFlight = false;

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await AppConstants.initialize();

  final prefs = await SharedPreferences.getInstance();
  await _primeApiFromPrefs(prefs);

  var intervalSeconds = prefs.getInt(_kPrefInterval) ?? 60;
  if (intervalSeconds < 1) intervalSeconds = 60;
  var distanceMeters = prefs.getInt(_kPrefDistance) ?? 30;
  var syncIntervalSeconds = _normalizeSyncInterval(
    prefs.getInt(_kPrefSyncInterval) ?? _kDefaultSyncIntervalSeconds,
  );
  var trackingType = prefs.getString(_kPrefType) ?? 'both';

  // Persisted across service restarts so a killed/restarted service does not
  // reset into an upload storm. If this is a first run, start the window now.
  _lastFlushAt = _readUtc(prefs, _kPrefLastFlushAt);
  if (_lastFlushAt == null) {
    _lastFlushAt = _nowUtc();
    await _writeUtc(prefs, _kPrefLastFlushAt, _lastFlushAt!);
  }
  _lastStoredLat = null;
  _lastStoredLng = null;

  Timer? timer;
  void restartTimer() {
    timer?.cancel();
    timer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _sample(
        service,
        distanceMeters: distanceMeters,
        syncIntervalSeconds: syncIntervalSeconds,
        trackingType: trackingType,
      ),
    );
  }

  service.on('stopService').listen((_) async {
    timer?.cancel();
    await service.stopSelf();
  });

  // Live config push from the UI isolate (e.g. admin changed settings, or a new
  // shift started). Closures read these locals on each tick, so distance/sync/
  // type update instantly; only an interval change needs the timer rebuilt.
  service.on('updateConfig').listen((event) {
    final nextDistance = (event?['distance'] as num?)?.toInt();
    final nextSync = (event?['syncInterval'] as num?)?.toInt();
    final nextType = event?['type'] as String?;
    if (nextDistance != null) distanceMeters = nextDistance;
    if (nextSync != null) {
      syncIntervalSeconds = _normalizeSyncInterval(nextSync);
    }
    if (nextType != null) trackingType = nextType;

    final nextInterval = (event?['interval'] as num?)?.toInt();
    if (nextInterval != null &&
        nextInterval > 0 &&
        nextInterval != intervalSeconds) {
      intervalSeconds = nextInterval;
      restartTimer();
    }
  });

  // Checkout / immediate flush: drain the buffer, then acknowledge so the caller
  // can safely stop the service. Always acks, even on failure (buffer persists).
  service.on('forceSync').listen((_) async {
    try {
      await _flush(service, forced: true);
    } catch (_) {
      // Keep the buffer; retried on the next cycle or next shift.
    }
    service.invoke('syncDone');
  });

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'Attendance active',
      content: 'Sharing your location while you are checked in.',
    );
  }

  // Sample once immediately so the first checkpoint isn't a full interval away,
  // then on the periodic schedule.
  await _sample(
    service,
    distanceMeters: distanceMeters,
    syncIntervalSeconds: syncIntervalSeconds,
    trackingType: trackingType,
  );
  restartTimer();
}

/// Re-primes [ApiService.instance] in this isolate from persisted credentials,
/// and wires a token-refresh hook so long shifts survive access-token expiry.
Future<void> _primeApiFromPrefs(
  SharedPreferences prefs, {
  bool ensureOdooSession = false,
}) async {
  final accessToken = prefs.getString(AppConstants.accessTokenKey);
  var sessionId = prefs.getString(AppConstants.sessionIdKey);

  int? employeeId;
  final userDataRaw = prefs.getString(AppConstants.userDataKey);
  if (userDataRaw != null && userDataRaw.isNotEmpty) {
    try {
      final map = jsonDecode(userDataRaw);
      if (map is Map<String, dynamic>) {
        employeeId = (map['employee_id'] as num?)?.toInt();
      }
    } catch (_) {
      // Ignore malformed cache; sync will fail loudly and be skipped.
    }
  }

  ApiService.instance.updateAccessToken(accessToken);
  ApiService.instance.updateSessionId(sessionId);
  ApiService.instance.updateEmployeeId(employeeId);

  if (ensureOdooSession) {
    sessionId = await _bootstrapOdooSession(prefs, sessionId) ?? sessionId;
  }

  ApiService.onTokenExpired = () async {
    // Re-read from disk: the UI isolate rotates the refresh token too, and
    // SharedPreferences caches per isolate, so the value captured at prime
    // time can be a token the server has already superseded.
    await prefs.reload();
    final now = _nowUtc();
    final lastRefreshAttempt = _readUtc(prefs, _kPrefTokenRefreshAttemptAt);
    if (lastRefreshAttempt != null &&
        now.difference(lastRefreshAttempt) < _kTokenRefreshCooldown) {
      return null;
    }
    await _writeUtc(prefs, _kPrefTokenRefreshAttemptAt, now);

    final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final latestSessionId =
          await _bootstrapOdooSession(
            prefs,
            prefs.getString(AppConstants.sessionIdKey) ?? sessionId,
          ) ??
          prefs.getString(AppConstants.sessionIdKey) ??
          sessionId;
      final authService = AuthService()..updateSessionId(latestSessionId);
      final tokens = await authService.refresh(refreshToken);
      await prefs.setString(AppConstants.accessTokenKey, tokens.accessToken);
      await prefs.setString(AppConstants.refreshTokenKey, tokens.refreshToken);
      ApiService.instance.updateAccessToken(tokens.accessToken);
      await prefs.remove(_kPrefTokenRefreshAttemptAt);
      return tokens.accessToken;
    } catch (_) {
      return null;
    }
  };
}

Future<String?> _bootstrapOdooSession(
  SharedPreferences prefs,
  String? currentSessionId,
) async {
  if (AppConstants.baseUrl.isEmpty) return currentSessionId;
  try {
    final authService = AuthService()..updateSessionId(currentSessionId);
    final sessionId = await authService.bootstrapOdooSession(
      baseUrl: AppConstants.baseUrl,
      dbName: AppConstants.dbName,
    );
    await prefs.setString(AppConstants.sessionIdKey, sessionId);
    ApiService.instance.updateSessionId(sessionId);
    return sessionId;
  } catch (e) {
    if (currentSessionId != null && currentSessionId.isNotEmpty) {
      ApiService.instance.updateSessionId(currentSessionId);
    }
    if (kDebugMode) {
      debugPrint('LocationTrackingService session bootstrap failed: $e');
    }
    return currentSessionId;
  }
}

/// One sampling cycle: verify still active, grab a GPS fix, apply the distance
/// filter, buffer it, and flush if the sync window has elapsed.
Future<void> _sample(
  ServiceInstance service, {
  required int distanceMeters,
  required int syncIntervalSeconds,
  required String trackingType,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(_kPrefActive) != true) {
      await service.stopSelf();
      return;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) return;

    // Distance filter: for distance/both modes, only store a point once the
    // device has moved far enough from the last stored one. 'time' mode stores
    // every sample. The very first point of a shift always stores (no anchor).
    final applyDistanceFilter = trackingType != 'time' && distanceMeters > 0;
    if (applyDistanceFilter &&
        _lastStoredLat != null &&
        _lastStoredLng != null) {
      final moved = Geolocator.distanceBetween(
        _lastStoredLat!,
        _lastStoredLng!,
        position.latitude,
        position.longitude,
      );
      if (moved < distanceMeters) {
        // Not moved enough to log, but the sync window may still be due.
        await _maybeFlush(service, syncIntervalSeconds);
        await _publishSnapshot(prefs);
        return;
      }
    }

    final recordedAt = _formatUtc(DateTime.now().toUtc());
    await LocationDbHelper.instance.insertLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: recordedAt,
      isMock: position.isMocked,
    );
    _lastStoredLat = position.latitude;
    _lastStoredLng = position.longitude;

    await _maybeFlush(service, syncIntervalSeconds);
    await _publishSnapshot(prefs);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Location sample failed: $e');
    }
  }
}

/// Flushes when at least [syncIntervalSeconds] have passed since the last one.
Future<void> _maybeFlush(
  ServiceInstance service,
  int syncIntervalSeconds,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final now = _nowUtc();
  final nextAllowed = _readUtc(prefs, _kPrefNextSyncAfter);
  if (nextAllowed != null && now.isBefore(nextAllowed)) return;

  final persistedLast = _readUtc(prefs, _kPrefLastFlushAt);
  if (persistedLast != null) _lastFlushAt = persistedLast;

  final last = _lastFlushAt;
  if (last == null) {
    _lastFlushAt = now;
    await _writeUtc(prefs, _kPrefLastFlushAt, now);
    return;
  }

  final interval = _normalizeSyncInterval(syncIntervalSeconds);
  if (now.difference(last).inSeconds >= interval) {
    await _flush(service);
  }
}

/// Uploads the whole SQLite buffer as one batch. On success, deletes the synced
/// rows and resets the flush window. On failure, leaves everything intact to
/// retry — so an offline stretch simply accumulates and delivers later. The
/// outcome (ok/error + message) is recorded to prefs so the in-app Location
/// Buffer screen can show *why* a sync failed without needing logcat.
Future<void> _flush(ServiceInstance service, {bool forced = false}) async {
  if (_flushInFlight) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final now = _nowUtc();
  if (!forced) {
    final nextAllowed = _readUtc(prefs, _kPrefNextSyncAfter);
    if (nextAllowed != null && now.isBefore(nextAllowed)) return;
  }

  final lockAt = _readUtc(prefs, _kPrefFlushLockAt);
  if (lockAt != null && now.difference(lockAt) < _kFlushLockTtl) return;

  _flushInFlight = true;
  await _writeUtc(prefs, _kPrefFlushLockAt, now);

  try {
    await _primeApiFromPrefs(prefs, ensureOdooSession: true);
    final rows = await LocationDbHelper.instance.getBufferedLocations();
    if (rows.isEmpty) {
      await _recordFlushSuccess(prefs);
      return;
    }

    final maxId = rows.last['id'] as int;
    final locations = rows
        .map(
          (r) => {
            'latitude': r['latitude'],
            'longitude': r['longitude'],
            'recorded_at': r['recorded_at'],
            'is_mock': (r['is_mock'] as int) == 1,
          },
        )
        .toList();

    try {
      final response = await ApiService.instance.syncEmployeeLocations(
        locations: locations,
      );
      final ok = response['success'] == true;
      if (kDebugMode) {
        debugPrint('Location flush (${locations.length} pts): $response');
      }
      if (ok) {
        await LocationDbHelper.instance.deleteUpToId(maxId);
        await _recordFlushSuccess(prefs);
        final synced = response['data'] is Map
            ? (response['data'] as Map)['synced_count']
            : locations.length;
        await _recordSync(
          prefs,
          true,
          locations.length,
          'Uploaded ${locations.length}, server stored $synced',
        );

        final responseData = response['data'];
        final autoCheckedOut = responseData is Map ? responseData['auto_checked_out_visits'] : null;
        if (autoCheckedOut is List && autoCheckedOut.isNotEmpty) {
          service.invoke('autoCheckOutVisits', {'visits': autoCheckedOut});
          try {
            await prefs.setString(
              'last_auto_checked_out_visits',
              jsonEncode(autoCheckedOut),
            );
          } catch (_) {}
        }
      } else {
        await _recordFlushFailure(
          prefs,
          locations.length,
          response['message']?.toString() ?? 'Server returned success:false',
        );
      }
    } catch (e) {
      // Network error, auth failure, or DB lock: keep the buffer and back off.
      await _recordFlushFailure(
        prefs,
        locations.length,
        e.toString().replaceAll('Exception: ', ''),
      );
      if (kDebugMode) {
        debugPrint('Location flush failed: $e');
      }
    }
  } finally {
    _flushInFlight = false;
    await _releaseFlushLock(prefs, now);
  }
}

Future<void> _recordFlushSuccess(SharedPreferences prefs) async {
  final now = _nowUtc();
  _lastFlushAt = now;
  await _writeUtc(prefs, _kPrefLastFlushAt, now);
  await prefs.remove(_kPrefNextSyncAfter);
  await prefs.remove(_kPrefSyncFailureCount);
}

Future<void> _recordFlushFailure(
  SharedPreferences prefs,
  int count,
  String message,
) async {
  final failureCount = (prefs.getInt(_kPrefSyncFailureCount) ?? 0) + 1;
  await prefs.setInt(_kPrefSyncFailureCount, failureCount);
  await _writeUtc(
    prefs,
    _kPrefNextSyncAfter,
    _nowUtc().add(_syncBackoffFor(message, failureCount)),
  );
  await _recordSync(prefs, false, count, message);
}

DateTime _nowUtc() => DateTime.now().toUtc();

DateTime? _readUtc(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

Future<void> _writeUtc(
  SharedPreferences prefs,
  String key,
  DateTime value,
) async {
  await prefs.setString(key, value.toUtc().toIso8601String());
}

Future<void> _releaseFlushLock(
  SharedPreferences prefs,
  DateTime claimedAt,
) async {
  await prefs.reload();
  final lockAt = _readUtc(prefs, _kPrefFlushLockAt);
  if (lockAt == null) return;

  final claim = claimedAt.toUtc();
  if (lockAt.isAtSameMomentAs(claim) ||
      _nowUtc().difference(lockAt) >= _kFlushLockTtl) {
    await prefs.remove(_kPrefFlushLockAt);
  }
}

int _normalizeSyncInterval(int seconds) {
  if (seconds < _kMinimumSyncIntervalSeconds) {
    return _kDefaultSyncIntervalSeconds;
  }
  return seconds;
}

Duration _syncBackoffFor(String message, int failureCount) {
  final lower = message.toLowerCase();
  if (lower.contains('429') || lower.contains('too many requests')) {
    return const Duration(hours: 1);
  }
  if (lower.contains('token') ||
      lower.contains('session') ||
      lower.contains('auth') ||
      lower.contains('401') ||
      lower.contains('403')) {
    return const Duration(minutes: 15);
  }

  var minutes = 5;
  for (var i = 1; i < failureCount; i++) {
    minutes *= 2;
    if (minutes >= 60) return const Duration(hours: 1);
  }
  return Duration(minutes: minutes);
}

/// Records the last flush outcome for the in-app diagnostic screen.
Future<void> _recordSync(
  SharedPreferences prefs,
  bool ok,
  int count,
  String msg,
) async {
  try {
    await prefs.setString(
      'loc_last_sync',
      jsonEncode({
        'ok': ok,
        'count': count,
        'msg': msg,
        'at': _formatUtc(_nowUtc()),
      }),
    );
  } catch (_) {
    // Diagnostics are best-effort; never let them break tracking.
  }
}

/// Publishes a snapshot of the buffer to prefs so the in-app Location Buffer
/// screen can render it WITHOUT opening the SQLite file from the UI isolate
/// (sqflite does not support one database across two isolates — doing so
/// locks out the background isolate's own reads/writes and stalls syncing).
Future<void> _publishSnapshot(SharedPreferences prefs) async {
  try {
    final rows = await LocationDbHelper.instance.getBufferedLocations();
    final recent = rows.reversed
        .take(25)
        .map(
          (r) => {
            'id': r['id'],
            'lat': r['latitude'],
            'lng': r['longitude'],
            'at': r['recorded_at'],
            'mock': (r['is_mock'] as int) == 1,
          },
        )
        .toList();
    await prefs.setInt('loc_buffer_count', rows.length);
    await prefs.setString('loc_buffer_recent', jsonEncode(recent));
  } catch (_) {
    // Best-effort snapshot; ignore.
  }
}

/// Server-compatible UTC datetime string, `YYYY-MM-DD HH:MM:SS`.
String _formatUtc(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
