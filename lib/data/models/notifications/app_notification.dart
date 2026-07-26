import 'package:secondary_sales/core/util/parse.dart';

/// A single in-app notification returned by `/mobile/notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.link,
  });

  final int id;
  final String type;
  final String typeLabel;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  /// Generic record reference used for deep-linking, or null when the
  /// notification points at no record.
  final NotificationLink? link;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: asInt(map['id']),
      type: asNullableString(map['type']) ?? '',
      typeLabel: asNullableString(map['type_label']) ?? '',
      title: asNullableString(map['title']) ?? '',
      body: asNullableString(map['body']) ?? '',
      isRead: asBool(map['is_read']),
      createdAt: _parseServerTime(map['created_at']),
      link: NotificationLink.fromMapOrNull(asMapOrNull(map['link'])),
    );
  }

  /// Odoo returns naive UTC ISO strings; mark as UTC then convert to local so
  /// the "x minutes ago" label is correct regardless of the device timezone.
  static DateTime? _parseServerTime(Object? value) {
    final raw = asNullableString(value);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final utc = parsed.isUtc
        ? parsed
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
          );
    return utc.toLocal();
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      typeLabel: typeLabel,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      link: link,
    );
  }
}

/// Model-agnostic pointer to the record a notification is about. `model` is an
/// Odoo model name (e.g. `sale.order`); the app's `NotificationRouter` maps it
/// to the right screen. Nothing here is sale-order-specific.
class NotificationLink {
  const NotificationLink({
    required this.model,
    required this.recordId,
    this.name,
    this.saleType,
    this.actionLink,
  });

  final String model;
  final int recordId;
  final String? name;
  final String? saleType;
  final String? actionLink;

  /// Returns null unless both a model and a non-zero record id are present.
  static NotificationLink? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    final model = asNullableString(map['model']);
    final recordId = asNonZeroInt(map['id']);
    if (model == null || recordId == null) return null;
    return NotificationLink(
      model: model,
      recordId: recordId,
      name: asNullableString(map['name']),
      saleType: asNullableString(map['sale_type']),
      actionLink: asNullableString(map['action_link']),
    );
  }
}

/// One page of notifications plus the caller's global unread count, as returned
/// by the list endpoint.
class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.total,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final int total;
}
