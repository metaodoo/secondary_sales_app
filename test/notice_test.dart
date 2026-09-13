import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/data/models/notifications/app_notice.dart';
import 'package:secondary_sales/data/models/notifications/notice_channel.dart';

void main() {
  group('AppNotice Model Tests', () {
    test('deserializes from Map properly', () {
      final map = {
        'id': 101,
        'channel_id': 5,
        'channel_name': 'Sales MT Announcements',
        'author_id': 12,
        'author_name': 'Regional Manager',
        'author_avatar_url': '/web/image/res.partner/12/avatar_128',
        'subject': 'Target Update for September',
        'body': '<p>Please see attached <b>targets</b>.</p>',
        'is_read': false,
        'created_at': '2026-09-09T10:00:00Z',
        'attachments': [
          {
            'id': 501,
            'name': 'Targets.pdf',
            'mimetype': 'application/pdf',
            'file_size': 1048576,
            'url': '/web/content/501?download=true',
          }
        ],
      };

      final notice = AppNotice.fromMap(map);

      expect(notice.id, 101);
      expect(notice.channelId, 5);
      expect(notice.channelName, 'Sales MT Announcements');
      expect(notice.authorName, 'Regional Manager');
      expect(notice.subject, 'Target Update for September');
      expect(notice.isRead, false);
      expect(notice.plainTextBody, 'Please see attached targets.');
      expect(notice.hasAttachments, true);
      expect(notice.attachments.length, 1);

      final att = notice.attachments.first;
      expect(att.name, 'Targets.pdf');
      expect(att.isPdf, true);
      expect(att.isImage, false);
      expect(att.formattedSize, '1.0 MB');
    });

    test('deserializes NoticeChannel from Map properly', () {
      final map = {
        'id': 5,
        'name': 'Sales MT Announcements',
        'description': 'Official channel for modern trade officers',
        'channel_type': 'group',
        'unread_count': 3,
        'member_count': 28,
      };

      final channel = NoticeChannel.fromMap(map);

      expect(channel.id, 5);
      expect(channel.name, 'Sales MT Announcements');
      expect(channel.unreadCount, 3);
      expect(channel.memberCount, 28);
    });
  });
}
