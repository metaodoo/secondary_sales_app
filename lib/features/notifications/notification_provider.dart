import 'package:flutter/foundation.dart';

import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/notifications/app_notification.dart';

/// Backs the in-app notification center: the paginated notification list, the
/// unread badge count, and read-state mutations. Fails soft — a failed fetch
/// surfaces [error] but never throws into the UI.
class NotificationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  static const int _pageSize = 20;

  final List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _onlyUnread = false;
  String? _error;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get onlyUnread => _onlyUnread;
  String? get error => _error;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);
  }

  /// Loads the first page, replacing the current list.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _apiService.fetchNotifications(
        limit: _pageSize,
        offset: 0,
        onlyUnread: _onlyUnread,
      );
      _notifications
        ..clear()
        ..addAll(page.notifications);
      _unreadCount = page.unreadCount;
      _hasMore = _notifications.length < page.total;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('Notifications refresh failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page when [hasMore].
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _apiService.fetchNotifications(
        limit: _pageSize,
        offset: _notifications.length,
        onlyUnread: _onlyUnread,
      );
      _notifications.addAll(page.notifications);
      _unreadCount = page.unreadCount;
      _hasMore =
          page.notifications.isNotEmpty && _notifications.length < page.total;
    } catch (e) {
      if (kDebugMode) debugPrint('Notifications loadMore failed: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refreshes just the unread badge (cheap; used on app resume, dashboard load,
  /// and when a push arrives).
  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _apiService.fetchUnreadCount();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Unread-count refresh failed: $e');
    }
  }

  /// Toggles the All/Unread filter and reloads.
  Future<void> setOnlyUnread(bool value) async {
    if (_onlyUnread == value) return;
    _onlyUnread = value;
    await refresh();
  }

  /// Marks one notification read (optimistic; reconciles the count from server).
  Future<void> markRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      if (_notifications[index].isRead) return;
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount -= 1;
      notifyListeners();
    }
    try {
      _unreadCount = await _apiService.markNotificationsRead([id]);
      // When viewing only unread, drop the now-read row from the list.
      if (_onlyUnread) _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('markRead failed: $e');
    }
  }

  /// Marks every notification read (optimistic).
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _unreadCount = 0;
    if (_onlyUnread) _notifications.clear();
    notifyListeners();
    try {
      _unreadCount = await _apiService.markAllNotificationsRead();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('markAllRead failed: $e');
    }
  }

  /// Called when a push arrives while the app is running: refresh the badge, and
  /// the list too if it has already been opened.
  Future<void> handleIncomingPush() async {
    await refreshUnreadCount();
    if (_notifications.isNotEmpty) {
      await refresh();
    }
  }

  void clearData({bool notify = true}) {
    _notifications.clear();
    _unreadCount = 0;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = false;
    _onlyUnread = false;
    _error = null;
    if (notify) notifyListeners();
  }
}
