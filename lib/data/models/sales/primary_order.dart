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
    final hName = hub is Map
        ? (hub['name'] ?? 'Unknown Hub').toString()
        : (map['partner_name'] != null && map['partner_name'] != false
            ? map['partner_name'].toString()
            : 'Unknown Hub');
    final hId = hub is Map ? asInt(hub['id']) : asInt(map['partner_id']);

    return PrimaryOrder(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      dateTime: dt,
      date: formattedDate,
      hubName: hName,
      hubId: hId,
      amount: asDouble(map['amount_total'] ?? map['amount']),
      state: (map['state'] ?? 'draft').toString(),
      lineCount: map['lines'] is List
          ? (map['lines'] as List).length
          : asInt(map['line_count'] ?? map['total_lines']),
      deliveryStatus:
          (map['delivery_status'] == null || map['delivery_status'] == false)
          ? 'no'
          : map['delivery_status'].toString(),
      currencySymbol: (map['currency_symbol'] ?? '৳').toString(),
    );
  }
}
