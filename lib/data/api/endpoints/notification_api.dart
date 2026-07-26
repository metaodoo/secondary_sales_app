part of '../api_service.dart';

/// In-app notification center endpoints.
extension NotificationApi on ApiService {
  /// Fetches a page of the caller's notifications (newest first) plus the
  /// caller's global unread count. `onlyUnread` restricts to unread rows.
  Future<NotificationPage> fetchNotifications({
    int limit = 20,
    int offset = 0,
    bool onlyUnread = false,
  }) async {
    final result = await _post(AppConstants.mobileNotificationsEndpoint, {
      'limit': limit,
      'offset': offset,
      if (onlyUnread) 'only_unread': true,
    });
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to load notifications');
    }
    final data = asMap(result['data']);
    final rawList = data['notifications'];
    final items = (rawList is List ? rawList : const [])
        .map((e) => AppNotification.fromMap(asMap(e)))
        .toList();
    return NotificationPage(
      notifications: items,
      unreadCount: asInt(data['unread_count']),
      total: asInt(data['total']),
    );
  }

  /// Lightweight unread-count fetch for the bell badge.
  Future<int> fetchUnreadCount() async {
    final result = await _post(
      AppConstants.mobileNotificationsUnreadCountEndpoint,
      const <String, dynamic>{},
    );
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to load unread count');
    }
    return asInt(asMap(result['data'])['unread_count']);
  }

  /// Marks the given notifications read; returns the updated unread count.
  Future<int> markNotificationsRead(List<int> ids) async {
    final result = await _post(AppConstants.mobileNotificationsMarkReadEndpoint, {
      'notification_ids': ids,
    });
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to mark notifications read');
    }
    return asInt(asMap(result['data'])['unread_count']);
  }

  /// Marks every unread notification read; returns 0.
  Future<int> markAllNotificationsRead() async {
    final result = await _post(
      AppConstants.mobileNotificationsMarkAllReadEndpoint,
      const <String, dynamic>{},
    );
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to mark all read');
    }
    return asInt(asMap(result['data'])['unread_count']);
  }
}
