part of '../api_service.dart';

/// Notice Board (Discuss Channel Broadcasts) endpoints.
extension NoticeApi on ApiService {
  /// Fetches a page of channel notices for the authenticated user's channels.
  Future<NoticePage> fetchNotices({
    int limit = 20,
    int offset = 0,
    int? channelId,
    String? search,
    bool onlyUnread = false,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (channelId != null) 'channel_id': channelId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (onlyUnread) 'only_unread': true,
    };

    final result = await _post(AppConstants.mobileNoticesEndpoint, params);
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to load notices');
    }
    final data = asMap(result['data']);
    final rawList = data['notices'];
    final items = (rawList is List ? rawList : const [])
        .map((e) => AppNotice.fromMap(asMap(e)))
        .toList();
    return NoticePage(
      notices: items,
      unreadCount: asInt(data['unread_count']),
      total: asInt(data['total']),
    );
  }

  /// Fetches the notice channels the employee is a member of.
  Future<List<NoticeChannel>> fetchNoticeChannels() async {
    final result = await _post(
      AppConstants.mobileNoticeChannelsEndpoint,
      const <String, dynamic>{},
    );
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to load notice channels');
    }
    final data = asMap(result['data']);
    final rawList = data['channels'];
    return (rawList is List ? rawList : const [])
        .map((e) => NoticeChannel.fromMap(asMap(e)))
        .toList();
  }

  /// Marks a specific notice message or an entire channel as read.
  Future<int> markNoticeRead({int? noticeId, int? channelId}) async {
    final params = <String, dynamic>{
      if (noticeId != null) 'notice_id': noticeId,
      if (channelId != null) 'channel_id': channelId,
    };
    final result = await _post(AppConstants.mobileNoticeMarkReadEndpoint, params);
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to mark notice read');
    }
    return asInt(asMap(result['data'])['unread_count']);
  }

  /// Lightweight unread count for notice board.
  Future<int> fetchNoticeUnreadCount() async {
    final result = await _post(
      AppConstants.mobileNoticeUnreadCountEndpoint,
      const <String, dynamic>{},
    );
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to load notice unread count');
    }
    return asInt(asMap(result['data'])['unread_count']);
  }
}
