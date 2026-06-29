import 'package:secondary_sales/core/util/parse.dart';
class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    this.code,
    this.stockLocation,
  });

  final int id;
  final String name;
  final String? code;
  final StockLocation? stockLocation;

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    final location = map['stock_location'];
    return Warehouse(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      code: asNullableString(map['code']),
      stockLocation: location is Map
          ? StockLocation.fromMap(location.cast<String, dynamic>())
          : null,
    );
  }
}

class StockLocation {
  const StockLocation({
    required this.id,
    required this.name,
    this.usage,
    this.completeName,
  });

  final int id;
  final String name;
  final String? usage;
  final String? completeName;

  factory StockLocation.fromMap(Map<String, dynamic> map) {
    return StockLocation(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      usage: asNullableString(map['usage']),
      completeName: asNullableString(
        map['complete_name'] ?? map['display_name'],
      ),
    );
  }
}

class AvailableLot {
  const AvailableLot({
    required this.lotId,
    required this.lotName,
    required this.productId,
    required this.availableQty,
    this.uomName,
    this.locationName,
  });

  final int lotId;
  final String lotName;
  final int productId;
  final double availableQty;
  final String? uomName;
  final String? locationName;

  factory AvailableLot.fromMap(Map<String, dynamic> map) {
    final uom = map['uom'];
    final location = map['location'];
    return AvailableLot(
      lotId: asInt(map['lot_id']),
      lotName: (map['lot_name'] ?? '').toString(),
      productId: asInt(map['product_id']),
      availableQty: asDouble(map['available_qty']),
      uomName: uom is Map ? asNullableString(uom['name']) : null,
      locationName: location is Map
          ? asNullableString(location['name'])
          : null,
    );
  }
}

