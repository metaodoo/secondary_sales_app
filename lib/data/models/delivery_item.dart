import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/data/models/contacts/res_zone.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';

class DeliveryListResult {
  final List<DeliveryItem> items;
  final List<ResZone> zones;
  final List<StockLocation> locations;
  final List<DeliveryOutletFilter> outlets;
  final int total;

  const DeliveryListResult({
    required this.items,
    this.zones = const [],
    this.locations = const [],
    this.outlets = const [],
    this.total = 0,
  });
}

class DeliveryOutletFilter {
  final int id;
  final String name;
  final String? ssCode;
  final int? zoneId;
  final String? zoneName;

  const DeliveryOutletFilter({
    required this.id,
    required this.name,
    this.ssCode,
    this.zoneId,
    this.zoneName,
  });

  factory DeliveryOutletFilter.fromMap(Map<String, dynamic> map) {
    return DeliveryOutletFilter(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      ssCode: asNullableString(map['ss_code']),
      zoneId: asIntOrNull(map['zone_id']),
      zoneName: asNullableString(map['zone_name']),
    );
  }
}

class DeliveryItem {
  final int id;
  final String name;
  final String state;
  final String? businessType;
  final String? ssPickingType;
  final int? partnerId;
  final String? partnerName;
  final String? partnerSsCode;
  final int? zoneId;
  final String? zoneName;
  final int? deliveryManId;
  final String? deliveryManName;
  final int? locationId;
  final String? locationName;
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
    this.businessType,
    this.ssPickingType,
    this.partnerId,
    this.partnerName,
    this.partnerSsCode,
    this.zoneId,
    this.zoneName,
    this.deliveryManId,
    this.deliveryManName,
    this.locationId,
    this.locationName,
    this.createdDate,
    this.scheduledDate,
    this.dateDone,
    this.origin,
    this.saleId,
    this.saleName,
  });

  factory DeliveryItem.fromMap(Map<String, dynamic> map) {
    final partner = map['partner'] is Map ? map['partner'] : null;
    final zone = partner != null && partner['zone'] is Map ? partner['zone'] : null;
    final deliveryMan = map['delivery_man'] is Map ? map['delivery_man'] : null;
    final location = map['location'] is Map ? map['location'] : null;

    return DeliveryItem(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      state: map['state'] ?? 'draft',
      businessType: map['business_type']?.toString(),
      ssPickingType: map['ss_picking_type']?.toString(),
      partnerId: partner != null ? asInt(partner['id']) : null,
      partnerName: partner?['name']?.toString(),
      partnerSsCode: partner?['ss_code']?.toString(),
      zoneId: zone != null ? asInt(zone['id']) : null,
      zoneName: zone?['name']?.toString(),
      deliveryManId: deliveryMan != null ? asInt(deliveryMan['id']) : null,
      deliveryManName: deliveryMan?['name']?.toString(),
      locationId: location != null ? asInt(location['id']) : null,
      locationName: location?['name']?.toString(),
      createdDate: asDateTime(map['created_date']),
      scheduledDate: asDateTime(map['scheduled_date']),
      dateDone: asDateTime(map['date_done']),
      origin: map['origin']?.toString(),
      saleId: asInt(map['sale_id']),
      saleName: map['sale_name']?.toString(),
    );
  }
}
