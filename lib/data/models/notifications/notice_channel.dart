import 'package:secondary_sales/core/util/parse.dart';

class NoticeChannel {
  const NoticeChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.channelType,
    required this.unreadCount,
    required this.memberCount,
  });

  final int id;
  final String name;
  final String description;
  final String channelType;
  final int unreadCount;
  final int memberCount;

  factory NoticeChannel.fromMap(Map<String, dynamic> map) {
    return NoticeChannel(
      id: asInt(map['id']),
      name: asString(map['name'], defaultValue: 'Channel'),
      description: asString(map['description']),
      channelType: asString(map['channel_type'], defaultValue: 'channel'),
      unreadCount: asInt(map['unread_count']),
      memberCount: asInt(map['member_count']),
    );
  }
}
