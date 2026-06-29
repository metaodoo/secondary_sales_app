import 'package:secondary_sales/core/util/parse.dart';
import 'sale_order_detail.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';

class DeliveryPrepare {
  const DeliveryPrepare({
    required this.orderId,
    required this.orderName,
    this.distributorName,
    required this.picking,
    required this.warehouses,
    required this.locations,
  });

  final int orderId;
  final String orderName;
  final String? distributorName;
  final DeliveryPicking picking;
  final List<Warehouse> warehouses;
  final List<StockLocation> locations;

  factory DeliveryPrepare.fromMap(Map<String, dynamic> map) {
    final order = (map['order'] as Map?)?.cast<String, dynamic>() ?? {};
    final distributor = order['distributor'];
    return DeliveryPrepare(
      orderId: asInt(order['id']),
      orderName: (order['name'] ?? '').toString(),
      distributorName: distributor is Map
          ? asNullableString(distributor['name'])
          : null,
      picking: DeliveryPicking.fromMap(
        (map['picking'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      warehouses: ((map['warehouses'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Warehouse.fromMap(item.cast<String, dynamic>()))
          .toList(),
      locations: ((map['locations'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => StockLocation.fromMap(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class DeliveryPicking {
  const DeliveryPicking({
    required this.id,
    required this.name,
    required this.state,
    this.sourceLocationId,
    this.sourceLocationName,
    this.destinationLocationId,
    this.destinationLocationName,
    required this.lines,
  });

  final int id;
  final String name;
  final String state;
  final int? sourceLocationId;
  final String? sourceLocationName;
  final int? destinationLocationId;
  final String? destinationLocationName;
  final List<DeliveryMoveLine> lines;

  factory DeliveryPicking.fromMap(Map<String, dynamic> map) {
    final sourceLoc = map['source_location'];
    final destLoc = map['destination_location'];
    return DeliveryPicking(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      sourceLocationId: sourceLoc is Map
          ? asNonZeroInt(sourceLoc['id'])
          : null,
      sourceLocationName: sourceLoc is Map
          ? asNullableString(sourceLoc['name'])
          : null,
      destinationLocationId: destLoc is Map
          ? asNonZeroInt(destLoc['id'])
          : null,
      destinationLocationName: destLoc is Map
          ? asNullableString(destLoc['name'])
          : null,
      lines: ((map['lines'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => DeliveryMoveLine.fromMap(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class DeliveryMoveLine {
  const DeliveryMoveLine({
    required this.moveId,
    this.saleLineId,
    this.product,
    required this.orderedQty,
    required this.quantityDone,
    required this.remainingQty,
    required this.defaultDeliveryQty,
    this.uomName,
    this.lotLines,
  });

  final int moveId;
  final int? saleLineId;
  final OrderProduct? product;
  final double orderedQty;
  final double quantityDone;
  final double remainingQty;
  final double defaultDeliveryQty;
  final String? uomName;
  final List<DeliveryLotLine>? lotLines;

  String get tracking => product?.tracking ?? 'none';
  bool get requiresLots => tracking != 'none';

  factory DeliveryMoveLine.fromMap(Map<String, dynamic> map) {
    final product = map['product'];
    final uom = map['product_uom'];
    return DeliveryMoveLine(
      moveId: asInt(map['move_id']),
      saleLineId: asNonZeroInt(map['sale_line_id']),
      product: product is Map
          ? OrderProduct.fromMap(product.cast<String, dynamic>())
          : null,
      orderedQty: asDouble(map['product_uom_qty']),
      quantityDone: asDouble(map['quantity_done']),
      remainingQty: asDouble(map['remaining_qty']),
      defaultDeliveryQty: asDouble(map['default_delivery_qty']),
      uomName: uom is Map ? asNullableString(uom['name']) : null,
      lotLines: ((map['lot_lines'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => DeliveryLotLine.fromMap(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class DeliveryLotLine {
  const DeliveryLotLine({
    required this.moveLineId,
    this.lotId,
    this.lotName,
    required this.quantity,
  });

  final int moveLineId;
  final int? lotId;
  final String? lotName;
  final double quantity;

  factory DeliveryLotLine.fromMap(Map<String, dynamic> map) {
    final lot = map['lot'];
    return DeliveryLotLine(
      moveLineId: asInt(map['move_line_id']),
      lotId: lot is Map ? asNonZeroInt(lot['id']) : null,
      lotName: lot is Map ? asNullableString(lot['name']) : null,
      quantity: asDouble(map['quantity']),
    );
  }
}

class DeliveryLineInput {
  DeliveryLineInput({
    required this.move,
    required this.quantityDone,
    List<DeliveryLotInput>? lots,
  }) : lots = lots ?? [];

  final DeliveryMoveLine move;
  double quantityDone;
  final List<DeliveryLotInput> lots;

  Map<String, dynamic> toPayload() {
    return {
      'move_id': move.moveId,
      'quantity_done': quantityDone,
      if (lots.isNotEmpty)
        'lot_lines': lots
            .where((lot) => lot.lot != null && lot.quantity > 0)
            .map((lot) => {'lot_id': lot.lot!.lotId, 'quantity': lot.quantity})
            .toList(),
    };
  }
}

class DeliveryLotInput {
  DeliveryLotInput({this.lot, this.quantity = 0});

  AvailableLot? lot;
  double quantity;
}

