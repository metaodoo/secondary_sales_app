import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class PrimaryOrder {
  final int id;
  final String name;
  final String date;
  final DateTime? dateTime;
  final String hubName;
  final int hubId;
  final double amount;
  final String state;
  final int lineCount;
  final String deliveryStatus;
  final String currencySymbol;

  PrimaryOrder({
    required this.id,
    required this.name,
    required this.date,
    this.dateTime,
    required this.hubName,
    required this.hubId,
    required this.amount,
    required this.state,
    required this.lineCount,
    required this.deliveryStatus,
    required this.currencySymbol,
  });

  factory PrimaryOrder.fromMap(Map<String, dynamic> map) {
    final hub = map['distributor'] ?? map['customer'];
    final dt = asDateTime(map['date_order']);
    final formattedDate = dt != null ? ssFormatDateTime(dt) : (map['date_order'] ?? '').toString();
    return PrimaryOrder(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      dateTime: dt,
      date: formattedDate,
      hubName: hub is Map ? (hub['name'] ?? 'Unknown Hub') : 'Unknown Hub',
      hubId: hub is Map ? asInt(hub['id']) : 0,
      amount: asDouble(map['amount_total']),
      state: map['state'] ?? 'draft',
      lineCount: map['lines'] is List ? (map['lines'] as List).length : 0,
      deliveryStatus:
          (map['delivery_status'] == null || map['delivery_status'] == false)
          ? 'no'
          : map['delivery_status'].toString(),
      currencySymbol: (map['currency_symbol'] ?? '৳').toString(),
    );
  }
}
