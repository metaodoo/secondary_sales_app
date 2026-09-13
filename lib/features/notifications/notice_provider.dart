import 'package:flutter/foundation.dart';

import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/notifications/app_notice.dart';
import 'package:secondary_sales/data/models/notifications/notice_channel.dart';

/// Backs the Notice Board: subscribed Discuss channels, paginated notices feed,
/// channel filtering, search, and mark-read tracking.
class NoticeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  static const int _pageSize = 20;

  final List<AppNotice> _notices = [];
  List<NoticeChannel> _channels = [];
  int? _selectedChannelId;
  String _searchQuery = '';
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _onlyUnread = false;
  String? _error;

  List<AppNotice> get notices => List.unmodifiable(_notices);
  List<NoticeChannel> get channels => List.unmodifiable(_channels);
  int? get selectedChannelId => _selectedChannelId;
  String get searchQuery => _searchQuery;
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

  /// Refreshes channel list and the first page of notices.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch subscribed channels
      try {
        _channels = await _apiService.fetchNoticeChannels();
      } catch (e) {
        if (kDebugMode) debugPrint('Notice channels fetch failed: $e');
      }

      // 2. Fetch notices
      final page = await _apiService.fetchNotices(
        limit: _pageSize,
        offset: 0,
        channelId: _selectedChannelId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        onlyUnread: _onlyUnread,
      );

      _notices
        ..clear()
        ..addAll(page.notices);
      _unreadCount = page.unreadCount;
      _hasMore = _notices.length < page.total;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('Notices refresh failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page of notices.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _apiService.fetchNotices(
        limit: _pageSize,
        offset: _notices.length,
        channelId: _selectedChannelId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        onlyUnread: _onlyUnread,
      );

      _notices.addAll(page.notices);
      _unreadCount = page.unreadCount;
      _hasMore = page.notices.isNotEmpty && _notices.length < page.total;
    } catch (e) {
      if (kDebugMode) debugPrint('Notices loadMore failed: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Filters feed by a specific channel (or null for all channels).
  Future<void> selectChannel(int? channelId) async {
    if (_selectedChannelId == channelId) return;
    _selectedChannelId = channelId;
    await refresh();
  }

  /// Sets the search term and reloads.
  Future<void> setSearchQuery(String query) async {
    if (_searchQuery == query) return;
    _searchQuery = query;
    await refresh();
  }

  /// Toggles the All/Unread filter and reloads.
  Future<void> setOnlyUnread(bool value) async {
    if (_onlyUnread == value) return;
    _onlyUnread = value;
    await refresh();
  }

  /// Refreshes just the unread badge count.
  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _apiService.fetchNoticeUnreadCount();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Notice unread-count refresh failed: $e');
    }
  }

  /// Marks a specific notice read and updates local state.
  Future<void> markNoticeRead(int noticeId) async {
    final idx = _notices.indexWhere((n) => n.id == noticeId);
    if (idx != -1 && !_notices[idx].isRead) {
      final old = _notices[idx];
      _notices[idx] = AppNotice(
        id: old.id,
        channelId: old.channelId,
        channelName: old.channelName,
        authorId: old.authorId,
        authorName: old.authorName,
        authorAvatarUrl: old.authorAvatarUrl,
        subject: old.subject,
        body: old.body,
        isRead: true,
        createdAt: old.createdAt,
        attachments: old.attachments,
      );
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }

    try {
      _unreadCount = await _apiService.markNoticeRead(noticeId: noticeId);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to mark notice read: $e');
    }
  }

  /// Marks all messages in a specific channel read.
  Future<void> markChannelRead(int channelId) async {
    for (var i = 0; i < _notices.length; i++) {
      if (_notices[i].channelId == channelId && !_notices[i].isRead) {
        final old = _notices[i];
        _notices[i] = AppNotice(
          id: old.id,
          channelId: old.channelId,
          channelName: old.channelName,
          authorId: old.authorId,
          authorName: old.authorName,
          authorAvatarUrl: old.authorAvatarUrl,
          subject: old.subject,
          body: old.body,
          isRead: true,
          createdAt: old.createdAt,
          attachments: old.attachments,
        );
      }
    }
    notifyListeners();

    try {
      _unreadCount = await _apiService.markNoticeRead(channelId: channelId);
      // Refresh channels to update their individual unread badges
      _channels = await _apiService.fetchNoticeChannels();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to mark channel read: $e');
    }
  }
}
