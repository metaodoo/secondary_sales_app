import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/services/push_notification_service.dart';
import 'package:secondary_sales/data/models/auth/mobile_auth_session.dart';
import 'package:secondary_sales/data/api/auth_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  MobileAuthSession? _session;
  String? _odooSessionId;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _error;

  MobileAuthSession? get session => _session;
  MobileAuthUser? get user => _session?.user;
  int? get employeeId => _session?.user.employeeId;
  String? get accessToken => _session?.accessToken;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _session != null;
  bool get isConnectionConfigured => AppConstants.hasSavedConnection;
  String? get sessionId => _session?.sessionId ?? _odooSessionId;
  String get baseUrl => AppConstants.baseUrl;
  String get dbName => AppConstants.dbName;
  bool get canAccessDealers {
    final groupCode = _session?.user.groupCode?.trim().toLowerCase();
    if (groupCode != null && groupCode.isNotEmpty) {
      return groupCode != 'so';
    }
    final role = _session?.user.role?.trim().toLowerCase();
    return role != 'so' && role != 'sales officer';
  }

  bool get canAccessPrimarySales {
    // By default, Primary Sales (Company -> Distributor) is restricted to managers/TSMs
    final groupCode = _session?.user.groupCode?.trim().toLowerCase();
    if (groupCode != null && groupCode.isNotEmpty) {
      return groupCode != 'so';
    }
    final role = _session?.user.role?.trim().toLowerCase();
    return role != 'so' && role != 'sales officer';
  }

  bool get canAccessSecondarySales {
    // Secondary Sales (Distributor -> Outlet) is accessible by SOs and TSMs
    return true;
  }

  Future<List<String>> fetchDatabases(String baseUrl) {
    return _authService.fetchDatabaseList(baseUrl);
  }

  Future<void> setupConnection({
    required String baseUrl,
    required String dbName,
  }) async {
    final sessionId = await _authService.bootstrapOdooSession(
      baseUrl: baseUrl,
      dbName: dbName,
    );
    await AppConstants.saveConnection(baseUrl: baseUrl, dbName: dbName);
    _odooSessionId = sessionId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionIdKey, sessionId);
    notifyListeners();
  }

  Future<void> restoreSession() async {
    _isInitializing = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(AppConstants.userDataKey);
      final accessToken = prefs.getString(AppConstants.accessTokenKey);
      final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
      final sessionId = prefs.getString(AppConstants.sessionIdKey);
      final tokenType = prefs.getString(AppConstants.tokenTypeKey) ?? 'Bearer';
      final expiresAtValue = prefs.getString(AppConstants.tokenExpiresAtKey);
      _odooSessionId = sessionId;
      _authService.updateSessionId(sessionId);

      if (userData == null || accessToken == null || refreshToken == null) {
        _session = null;
        return;
      }

      final userMap = jsonDecode(userData);
      if (userMap is! Map<String, dynamic>) {
        await _clearStoredSession(prefs);
        _session = null;
        return;
      }

      final expiresAt = DateTime.tryParse(expiresAtValue ?? '');
      _session = MobileAuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        sessionId: sessionId ?? '',
        tokenType: tokenType,
        expiresIn: 0,
        expiresAt: expiresAt,
        user: MobileAuthUser.fromMap(userMap),
      );
      _odooSessionId = _session!.sessionId;
      _authService.updateSessionId(_session!.sessionId);

      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        await refreshSession();
      } else {
        unawaited(
          PushNotificationService.bindAuthenticatedSession(
            accessToken: _session!.accessToken,
            sessionId: _session!.sessionId,
          ),
        );
      }
    } catch (e) {
      _error = e.toString();
      _session = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String login, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final session = await _authService.login(
        login: login,
        password: password,
      );
      if (session.user.employeeId == null) {
        throw Exception('No employee is linked with this mobile user.');
      }
      _session = session;
      _odooSessionId = session.sessionId;
      _authService.updateSessionId(session.sessionId);
      await _storeSession(session);
      unawaited(
        PushNotificationService.bindAuthenticatedSession(
          accessToken: session.accessToken,
          sessionId: session.sessionId,
        ),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshSession() async {
    final current = _session;
    if (current == null || current.refreshToken.isEmpty) return false;

    try {
      _authService.updateSessionId(current.sessionId);
      final tokens = await _authService.refresh(current.refreshToken);
      final refreshed = current.copyWith(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        tokenType: tokens.tokenType,
        expiresIn: tokens.expiresIn,
        expiresAt: DateTime.now().add(Duration(seconds: tokens.expiresIn)),
      );
      _session = refreshed;
      _odooSessionId = refreshed.sessionId;
      await _storeSession(refreshed);
      unawaited(
        PushNotificationService.bindAuthenticatedSession(
          accessToken: refreshed.accessToken,
          sessionId: refreshed.sessionId,
        ),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      await logout(callServer: false);
      return false;
    }
  }

  Future<void> logout({bool callServer = true}) async {
    final accessToken = _session?.accessToken;
    final sessionId = _session?.sessionId ?? _odooSessionId;
    _authService.updateSessionId(sessionId);

    if (callServer && accessToken != null && accessToken.isNotEmpty) {
      await PushNotificationService.clearAuthenticatedSession(
        accessToken: accessToken,
        sessionId: sessionId,
      );
    } else {
      unawaited(PushNotificationService.clearAuthenticatedSession());
    }

    _session = null;
    _odooSessionId = sessionId;
    _error = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _clearStoredSession(prefs);

    if (callServer && accessToken != null && accessToken.isNotEmpty) {
      try {
        await _authService.logout(accessToken);
      } catch (_) {
        // Local logout should still succeed if the server session is already gone.
      }
    }
    _authService.updateSessionId(sessionId);
  }

  Future<void> _storeSession(MobileAuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.accessTokenKey, session.accessToken);
    await prefs.setString(AppConstants.refreshTokenKey, session.refreshToken);
    await prefs.setString(AppConstants.sessionIdKey, session.sessionId);
    await prefs.setString(AppConstants.tokenTypeKey, session.tokenType);
    await prefs.setString(AppConstants.userRoleKey, session.user.role ?? '');
    await prefs.setString(
      AppConstants.userDataKey,
      jsonEncode(session.user.toMap()),
    );
    if (session.expiresAt != null) {
      await prefs.setString(
        AppConstants.tokenExpiresAtKey,
        session.expiresAt!.toIso8601String(),
      );
    }
  }

  Future<void> _clearStoredSession(SharedPreferences prefs) async {
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.tokenTypeKey);
    await prefs.remove(AppConstants.tokenExpiresAtKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.userDataKey);
  }
}
