import 'package:secondary_sales/core/util/parse.dart';

class DeliveryItem {
  final int id;
  final String name;
  final String state;
  final int? partnerId;
  final String? partnerName;
  final DateTime? createdDate;
  final DateTime? scheduledDate;
  final DateTime? dateDone;
  final String? origin;
  final int? saleId;
  final String? saleName;

  DeliveryItem({
    required this.id,
    required this.name,
    required this.state,
    this.partnerId,
    this.partnerName,
    this.createdDate,
    this.scheduledDate,
    this.dateDone,
    this.origin,
    this.saleId,
    this.saleName,
  });

  factory DeliveryItem.fromMap(Map<String, dynamic> map) {
    return DeliveryItem(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      state: map['state'] ?? 'draft',
      partnerId: map['partner']?['id'],
      partnerName: map['partner']?['name'],
      createdDate: asDateTime(map['created_date']),
      scheduledDate: asDateTime(map['scheduled_date']),
      dateDone: asDateTime(map['date_done']),
      origin: map['origin'],
      saleId: map['sale_id'],
      saleName: map['sale_name'],
    );
  }
}
