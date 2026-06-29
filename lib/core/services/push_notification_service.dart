import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/sales/screens/order_detail_screen.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final ApiService _apiService = ApiService.instance;

  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static String? _accessToken;
  static String? _sessionId;
  static int? _pendingSaleOrderId;
  static String? _pendingSaleOrderName;

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

    _openPendingSaleOrderIfPossible();
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
    _openPendingSaleOrderIfPossible();
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

  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'sale_order_confirmed' ||
        data['model'] != 'sale.order') {
      return;
    }

    final orderId = int.tryParse(data['id']?.toString() ?? '');
    if (orderId == null) {
      return;
    }

    _pendingSaleOrderId = orderId;
    _pendingSaleOrderName = data['name']?.toString();
    _openPendingSaleOrderIfPossible();
  }

  static void _openPendingSaleOrderIfPossible() {
    final orderId = _pendingSaleOrderId;
    final navigator = _navigatorKey?.currentState;
    if (orderId == null || navigator == null || _accessToken == null) {
      return;
    }

    _pendingSaleOrderId = null;
    final fallbackName = _pendingSaleOrderName ?? 'Sale Order #$orderId';
    _pendingSaleOrderName = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentNavigator = _navigatorKey?.currentState;
      if (currentNavigator == null) {
        _pendingSaleOrderId = orderId;
        _pendingSaleOrderName = fallbackName;
        return;
      }
      currentNavigator.push(
        MaterialPageRoute(
          builder: (_) =>
              OrderDetailScreen(orderId: orderId, fallbackName: fallbackName),
        ),
      );
    });
  }
}
