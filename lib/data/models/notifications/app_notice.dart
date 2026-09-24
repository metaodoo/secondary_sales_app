import 'package:secondary_sales/core/util/parse.dart';

class NoticeAttachment {
  const NoticeAttachment({
    required this.id,
    required this.name,
    required this.mimetype,
    required this.fileSize,
    required this.url,
  });

  final int id;
  final String name;
  final String mimetype;
  final int fileSize;
  final String url;

  factory NoticeAttachment.fromMap(Map<String, dynamic> map) {
    return NoticeAttachment(
      id: asInt(map['id']),
      name: asString(map['name']),
      mimetype: asString(map['mimetype']),
      fileSize: asInt(map['file_size']),
      url: asString(map['url']),
    );
  }

  bool get isImage =>
      mimetype.startsWith('image/') ||
      name.toLowerCase().endsWith('.png') ||
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg');

  bool get isPdf =>
      mimetype == 'application/pdf' || name.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.channelId,
    required this.channelName,
    this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.subject,
    required this.body,
    required this.isRead,
    this.createdAt,
    required this.attachments,
  });

  final int id;
  final int channelId;
  final String channelName;
  final int? authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String subject;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final List<NoticeAttachment> attachments;

  factory AppNotice.fromMap(Map<String, dynamic> map) {
    final rawAttachments = map['attachments'];
    final attachmentsList = (rawAttachments is List ? rawAttachments : const [])
        .map((e) => NoticeAttachment.fromMap(asMap(e)))
        .toList();

    return AppNotice(
      id: asInt(map['id']),
      channelId: asInt(map['channel_id']),
      channelName: asString(map['channel_name'], defaultValue: 'Notice'),
      authorId: map['author_id'] != null ? asInt(map['author_id']) : null,
      authorName: asString(map['author_name'], defaultValue: 'Announcement'),
      authorAvatarUrl: map['author_avatar_url'] != null
          ? asString(map['author_avatar_url'])
          : null,
      subject: asString(map['subject']),
      body: asString(map['body']),
      isRead: asBool(map['is_read']),
      createdAt: asDateTime(map['created_at']),
      attachments: attachmentsList,
    );
  }

  /// Plain text preview of the body with HTML tags stripped
  String get plainTextBody {
    final stripped = body.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
    return stripped.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool get hasAttachments => attachments.isNotEmpty;
}

class NoticePage {
  const NoticePage({
    required this.notices,
    required this.unreadCount,
    required this.total,
  });

  final List<AppNotice> notices;
  final int unreadCount;
  final int total;
}
