import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/notifications/app_notification.dart';
import 'package:secondary_sales/features/notifications/notification_router.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final ApiService _apiService = ApiService.instance;

  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static String? _accessToken;
  static String? _sessionId;

  /// A tap can arrive before the session is restored or the navigator exists
  /// (cold start from a notification), so the target is queued until both are.
  static NotificationLink? _pendingLink;

  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;

    try {
      await Firebase.initializeApp();
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Push notification initialization failed: $error');
      }
    }
  }

  static Future<void> bindAuthenticatedSession({
    required String accessToken,
    String? sessionId,
  }) async {
    _accessToken = accessToken;
    _sessionId = sessionId;
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);

    await registerCurrentDevice();
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });

    _openPendingNotificationIfPossible();
  }

  static Future<void> clearAuthenticatedSession({
    String? accessToken,
    String? sessionId,
  }) async {
    final token = await _safeGetToken();
    if (token != null && token.isNotEmpty && accessToken != null) {
      _apiService.updateAccessToken(accessToken);
      _apiService.updateSessionId(sessionId);
      try {
        await _apiService.unregisterMobileDevice(token);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Push device unregister failed: $error');
        }
      }
    }

    _accessToken = null;
    _sessionId = null;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  static Future<void> registerCurrentDevice() async {
    final token = await _safeGetToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _registerToken(token);
  }

  static void openPendingNotificationIfAny() {
    _openPendingNotificationIfPossible();
  }

  static Future<String?> _safeGetToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Could not read FCM token: $error');
      }
      return null;
    }
  }

  static Future<void> _registerToken(String token) async {
    final accessToken = _accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return;
    }

    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(_sessionId);
    try {
      await _apiService.registerMobileDevice(
        fcmToken: token,
        platform: _platform,
        deviceName: _deviceName,
        appVersion: _appVersion,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Push device registration failed: $error');
      }
    }
  }

  static String get _platform {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'android';
  }

  static String get _deviceName {
    if (kIsWeb) {
      return 'Web';
    }
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }

  static String get _appVersion => '1.0.0';

  /// Builds a record reference from an FCM data payload. Firebase requires every
  /// data value to be a string, so `id` arrives as "42" rather than 42 — the
  /// shared parse helpers in [NotificationLink] coerce it.
  static NotificationLink? _linkFromPushData(Map<String, dynamic> data) {
    return NotificationLink.fromMapOrNull({
      'model': data['model'],
      'id': data['id'],
      'name': data['name'],
      'sale_type': data['sale_type'],
      'action_link': data['action_link'],
    });
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final link = _linkFromPushData(message.data);
    if (link == null) {
      return;
    }

    _pendingLink = link;
    _openPendingNotificationIfPossible();
  }

  /// Routes through [NotificationRouter] — the same registry the in-app
  /// "Open record" button uses — so a push tap and a list tap land identically,
  /// and a new record type only has to be registered in one place. Models with
  /// no registered screen are silently ignored.
  static void _openPendingNotificationIfPossible() {
    final link = _pendingLink;
    final navigator = _navigatorKey?.currentState;
    if (link == null || navigator == null || _accessToken == null) {
      return;
    }

    _pendingLink = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentNavigator = _navigatorKey?.currentState;
      if (currentNavigator == null) {
        _pendingLink = link;
        return;
      }
      unawaited(NotificationRouter.open(currentNavigator, link));
    });
  }
}
