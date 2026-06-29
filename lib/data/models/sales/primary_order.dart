import 'package:secondary_sales/core/util/parse.dart';
class PrimaryOrder {
  final int id;
  final String name;
  final String date;
  final String hubName;
  final double amount;
  final String state;
  final int lineCount;
  final String deliveryStatus;

  PrimaryOrder({
    required this.id,
    required this.name,
    required this.date,
    required this.hubName,
    required this.amount,
    required this.state,
    required this.lineCount,
    required this.deliveryStatus,
  });

  factory PrimaryOrder.fromMap(Map<String, dynamic> map) {
    final hub = map['distributor'] ?? map['customer'];
    return PrimaryOrder(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      date: map['date_order'] ?? '',
      hubName: hub is Map ? (hub['name'] ?? 'Unknown Hub') : 'Unknown Hub',
      amount: asDouble(map['amount_total']),
      state: map['state'] ?? 'draft',
      lineCount: map['lines'] is List ? (map['lines'] as List).length : 0,
      deliveryStatus:
          (map['delivery_status'] == null || map['delivery_status'] == false)
          ? 'no'
          : map['delivery_status'].toString(),
    );
  }

}
