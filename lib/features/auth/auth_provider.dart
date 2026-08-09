import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secondary_sales/core/access/access_control.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/services/push_notification_service.dart';
import 'package:secondary_sales/data/models/auth/mobile_auth_session.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/api/auth_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  MobileAuthSession? _session;
  String? _odooSessionId;
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _tokenRefreshFailed = false;
  String? _error;

  MobileAuthSession? get session => _session;
  MobileAuthUser? get user => _session?.user;
  int? get employeeId => _session?.user.employeeId;
  String? get accessToken => _session?.accessToken;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _session != null;

  /// True when a refresh failed for network reasons and the session was kept.
  /// The session still looks authenticated but its access token is dead, so
  /// every request will 401 until a refresh succeeds. Deliberately not folded
  /// into [isAuthenticated] -- doing so would bounce the user to login on a
  /// dropped connection, which is exactly what the network-error branch of
  /// [refreshSession] exists to avoid.
  bool get tokenRefreshFailed => _tokenRefreshFailed;
  bool get isConnectionConfigured => AppConstants.hasSavedConnection;
  String? get sessionId => _session?.sessionId ?? _odooSessionId;
  String get baseUrl => AppConstants.baseUrl;
  String get dbName => AppConstants.dbName;

  /// Legacy "is manager/TSM (not a Sales Officer)" rule. Used as the fallback
  /// for module gates until the matching screen key is enforced server-side.
  bool get _legacyManagerAccess {
    final groupCode = _session?.user.groupCode?.trim().toLowerCase();
    if (groupCode != null && groupCode.isNotEmpty) {
      return groupCode != 'so';
    }
    final role = _session?.user.role?.trim().toLowerCase();
    return role != 'so' && role != 'sales officer';
  }

  bool get canAccessDealers =>
      _enforcedOr(AppScreen.dealers, _legacyManagerAccess);

  // By default, Primary Sales (Company -> Distributor) is restricted to managers/TSMs.
  bool get canAccessPrimarySales =>
      _enforcedOr(AppScreen.modulePrimary, _legacyManagerAccess);

  // Secondary Sales (Distributor -> Outlet) is accessible by SOs and TSMs.
  bool get canAccessSecondarySales =>
      _enforcedOr(AppScreen.moduleSecondary, true);

  /// Backend-driven screen/action access for the current user's group.
  /// Empty (allow-all) until the backend ships grants — see ACCESS_CONTROL_PLAN.md.
  AccessControl get access => _session?.access ?? const AccessControl();

  /// Whether a screen key (from `AppScreen`) should be shown.
  bool canView(String screenKey) => access.allows(screenKey);

  /// Whether an action key (from `AppAction`) should be shown/enabled.
  bool canDo(String actionKey) => access.allows(actionKey);

  /// Hybrid gate: use the registry only once [key] is enforced server-side;
  /// otherwise fall back to [legacy] so behavior is unchanged pre-rollout.
  bool _enforcedOr(String key, bool legacy) =>
      access.enforced.contains(key) ? access.allows(key) : legacy;

  // Returns/scrap field permissions — hybrid: the registry when the action is
  // enforced, else the group's permission flags from the login payload.
  bool get canViewAllReturns => _enforcedOr(
    AppAction.returnsViewAll,
    user?.permissions?.canViewAllReturns ?? false,
  );
  bool get canEditSoQty => _enforcedOr(
    AppAction.returnsEditSoQty,
    user?.permissions?.canEditSoQty ?? false,
  );
  bool get canEditWarehouseQty => _enforcedOr(
    AppAction.returnsEditWarehouseQty,
    user?.permissions?.canEditWarehouseQty ?? false,
  );
  bool get canEditEffectiveQty => _enforcedOr(
    AppAction.returnsEditEffectiveQty,
    user?.permissions?.canEditEffectiveQty ?? false,
  );
  bool get canSkipAttendanceGeo => _enforcedOr(
    AppAction.attendanceSkipGeo,
    user?.permissions?.skipAttendanceGeolocation ?? false,
  );

  bool canSaveReturnFor(String moduleType) => _enforcedOr(
    AppAction.returnSaveFor(moduleType),
    canEditSoQty || canEditWarehouseQty || canEditEffectiveQty,
  );
  bool canCancelReturnFor(String moduleType) => _enforcedOr(
    AppAction.returnCancelFor(moduleType),
    canEditSoQty || canEditWarehouseQty,
  );
  bool canValidateReturnFor(String moduleType) =>
      _enforcedOr(AppAction.returnValidateFor(moduleType), canEditWarehouseQty);
  bool canSaveScrapFor(String moduleType) => _enforcedOr(
    AppAction.scrapSaveFor(moduleType),
    canEditSoQty || canEditWarehouseQty || canEditEffectiveQty,
  );
  bool canCancelScrapFor(String moduleType) => _enforcedOr(
    AppAction.scrapCancelFor(moduleType),
    canEditSoQty || canEditWarehouseQty,
  );
  bool canValidateScrapFor(String moduleType) =>
      _enforcedOr(AppAction.scrapValidateFor(moduleType), canEditWarehouseQty);

  bool get canSaveReturn => canSaveReturnFor('primary');
  bool get canCancelReturn => canCancelReturnFor('primary');
  bool get canValidateReturn => canValidateReturnFor('primary');
  bool get canSaveScrap => canSaveScrapFor('primary');
  bool get canCancelScrap => canCancelScrapFor('primary');
  bool get canValidateScrap => canValidateScrapFor('primary');

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

      final accessRaw = prefs.getString(AppConstants.accessControlKey);
      var access = const AccessControl();
      if (accessRaw != null && accessRaw.isNotEmpty) {
        final decodedAccess = jsonDecode(accessRaw);
        if (decodedAccess is Map<String, dynamic>) {
          access = AccessControl.fromMap(decodedAccess);
        }
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
        access: access,
      );
      _odooSessionId = _session!.sessionId;
      _authService.updateSessionId(_session!.sessionId);
      ApiService.instance.updateAccessToken(_session!.accessToken);
      ApiService.instance.updateSessionId(_session!.sessionId);
      ApiService.instance.updateEmployeeId(_session!.user.employeeId);

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
      unawaited(refreshAccessControl());
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
      _tokenRefreshFailed = false;
      _authService.updateSessionId(session.sessionId);
      await _storeSession(session);
      unawaited(
        PushNotificationService.bindAuthenticatedSession(
          accessToken: session.accessToken,
          sessionId: session.sessionId,
        ),
      );
      unawaited(refreshAccessControl());
      unawaited(_autoSyncCatalogIfAllowed());
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
      ApiService.instance.updateAccessToken(refreshed.accessToken);
      ApiService.instance.updateSessionId(refreshed.sessionId);
      ApiService.instance.updateEmployeeId(refreshed.user.employeeId);
      await _storeSession(refreshed);
      unawaited(
        PushNotificationService.bindAuthenticatedSession(
          accessToken: refreshed.accessToken,
          sessionId: refreshed.sessionId,
        ),
      );
      _tokenRefreshFailed = false;
      // The session object was replaced. Without this, ProxyProvider.update
      // never runs and every dependent provider keeps the stale session.
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      final errStr = e.toString().toLowerCase();
      final isNetworkError = e is SocketException ||
          e is TimeoutException ||
          errStr.contains('socketexception') ||
          errStr.contains('timeoutexception') ||
          errStr.contains('connection') ||
          errStr.contains('timeout') ||
          errStr.contains('unreachable') ||
          errStr.contains('network') ||
          errStr.contains('handshake') ||
          errStr.contains('http 5'); // server errors (502, 503, 504) are temporary
      
      if (!isNetworkError) {
        await logout(callServer: false); // logout() notifies.
        return false;
      }

      // Keep the session so a flaky connection does not log the user out, but
      // record that its token is dead -- otherwise the app looks authenticated
      // while every request 401s, with nothing surfaced to the UI.
      _tokenRefreshFailed = true;
      notifyListeners();
      return false;
    }
  }

  /// Best-effort refresh of the current user's UI access grants (e.g. on
  /// resume or after an admin changes grants). Keeps the login-embedded access
  /// if the call fails (backend not upgraded, offline, etc.).
  Future<void> refreshAccessControl() async {
    final session = _session;
    if (session == null) return;
    try {
      _primeApiService(session);
      final access = await ApiService.instance.getAccessPermissions();
      _session = session.copyWith(access: access);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AppConstants.accessControlKey,
        jsonEncode(access.toMap()),
      );
      notifyListeners();
    } catch (_) {
      // Non-fatal: keep the existing (login-embedded) access.
    }
  }

  /// Pushes the app's screen/action catalog to Odoo so admins can grant it.
  /// Server-gated to groups with `can_manage_access`. Returns the sync counts
  /// and refreshes our own grants afterwards.
  Future<Map<String, dynamic>> syncAccessCatalog() async {
    final session = _session;
    if (session == null) {
      throw Exception('You must be logged in to sync the access catalog.');
    }
    _primeApiService(session);
    final result = await ApiService.instance.syncAccessCatalog(
      accessCatalog,
      appVersion: AppConstants.appVersion,
    );
    await refreshAccessControl();
    return result;
  }

  Future<void> _autoSyncCatalogIfAllowed() async {
    try {
      await syncAccessCatalog();
    } catch (_) {
      // Ignored for non-admin accounts without catalog sync permissions.
    }
  }

  void _primeApiService(MobileAuthSession session) {
    ApiService.instance.updateAccessToken(session.accessToken);
    ApiService.instance.updateSessionId(session.sessionId);
    ApiService.instance.updateEmployeeId(session.user.employeeId);
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
    _tokenRefreshFailed = false;
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
    await prefs.setString(
      AppConstants.accessControlKey,
      jsonEncode(session.access.toMap()),
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
    await prefs.remove(AppConstants.accessControlKey);
  }
}
