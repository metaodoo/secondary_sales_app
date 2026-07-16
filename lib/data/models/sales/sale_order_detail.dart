import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';

class SaleOrderDetail {
  const SaleOrderDetail({
    required this.id,
    required this.name,
    required this.state,
    required this.dateOrder,
    this.expectedDeliveryDate,
    this.distributor,
    this.warehouse,
    required this.amounts,
    required this.lines,
    required this.deliveryOrders,
    required this.canCancel,
    required this.canValidateDelivery,
    required this.deliveryStatus,
  });

  final int id;
  final String name;
  final String state;
  final String dateOrder;
  final String? expectedDeliveryDate;
  final OrderPartner? distributor;
  final Warehouse? warehouse;
  final OrderAmounts amounts;
  final List<SaleOrderDetailLine> lines;
  final List<DeliveryOrderSummary> deliveryOrders;
  final bool canCancel;
  final bool canValidateDelivery;
  final String deliveryStatus;

  factory SaleOrderDetail.fromMap(Map<String, dynamic> map) {
    final distributor = map['distributor'];
    final warehouseMap = map['warehouse'];
    return SaleOrderDetail(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      dateOrder: (map['date_order'] ?? '').toString(),
      expectedDeliveryDate: asNullableString(map['expected_delivery_date']),
      distributor: distributor is Map
          ? OrderPartner.fromMap(distributor.cast<String, dynamic>())
          : null,
      warehouse: warehouseMap is Map
          ? Warehouse.fromMap(warehouseMap.cast<String, dynamic>())
          : null,
      amounts: OrderAmounts.fromMap(
        (map['amounts'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      lines: ((map['lines'] as List?) ?? [])
          .whereType<Map>()
          .map(
            (item) => SaleOrderDetailLine.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
      deliveryOrders: ((map['delivery_orders'] as List?) ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                DeliveryOrderSummary.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
      canCancel: asBool(map['can_cancel']),
      canValidateDelivery: asBool(map['can_validate_delivery']),
      deliveryStatus:
          (map['delivery_status'] == null || map['delivery_status'] == false)
          ? 'no'
          : map['delivery_status'].toString(),
    );
  }
}

class OrderPartner {
  const OrderPartner({
    required this.id,
    required this.name,
    this.phone,
    this.address,
  });

  final int id;
  final String name;
  final String? phone;
  final String? address;

  factory OrderPartner.fromMap(Map<String, dynamic> map) {
    return OrderPartner(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      phone: asNullableString(map['phone']),
      address: asNullableString(map['address']),
    );
  }
}

class OrderAmounts {
  const OrderAmounts({
    required this.untaxed,
    required this.tax,
    required this.total,
    required this.discount,
    required this.receivable,
    this.currencySymbol,
  });

  final double untaxed;
  final double tax;
  final double total;
  final double discount;
  final double receivable;
  final String? currencySymbol;

  factory OrderAmounts.fromMap(Map<String, dynamic> map) {
    final currency = map['currency'];
    return OrderAmounts(
      untaxed: asDouble(map['amount_untaxed']),
      tax: asDouble(map['amount_tax']),
      total: asDouble(map['amount_total']),
      discount: asDouble(map['discount']),
      receivable: asDouble(map['receivable']),
      currencySymbol: currency is Map
          ? asNullableString(currency['symbol'])
          : null,
    );
  }
}

class SaleOrderDetailLine {
  const SaleOrderDetailLine({
    required this.id,
    this.product,
    required this.orderedQty,
    required this.deliveredQty,
    required this.balanceQty,
    required this.damagedQty,
    this.uomName,
    required this.priceUnit,
    required this.discount,
    required this.priceSubtotal,
    required this.priceTotal,
  });

  final int id;
  final OrderProduct? product;
  final double orderedQty;
  final double deliveredQty;
  final double balanceQty;
  final double damagedQty;
  final String? uomName;
  final double priceUnit;
  final double discount;
  final double priceSubtotal;
  final double priceTotal;

  factory SaleOrderDetailLine.fromMap(Map<String, dynamic> map) {
    final product = map['product'];
    final uom = map['product_uom'];
    return SaleOrderDetailLine(
      id: asInt(map['id']),
      product: product is Map
          ? OrderProduct.fromMap(product.cast<String, dynamic>())
          : null,
      orderedQty: asDouble(map['product_uom_qty']),
      deliveredQty: asDouble(map['qty_delivered']),
      balanceQty: asDouble(map['balance_qty']),
      damagedQty: asDouble(map['damaged_qty'] ?? 0.0),
      uomName: uom is Map ? asNullableString(uom['name']) : null,
      priceUnit: asDouble(map['price_unit']),
      discount: asDouble(map['discount']),
      priceSubtotal: asDouble(map['price_subtotal']),
      priceTotal: asDouble(map['price_total']),
    );
  }
}

class OrderProduct {
  const OrderProduct({
    required this.id,
    required this.name,
    this.defaultCode,
    this.tracking = 'none',
    this.qtyAvailable,
    this.distributorQtyAvailable,
  });

  final int id;
  final String name;
  final String? defaultCode;
  final String tracking;
  final double? qtyAvailable;
  final double? distributorQtyAvailable;

  factory OrderProduct.fromMap(Map<String, dynamic> map) {
    return OrderProduct(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      defaultCode: asNullableString(map['default_code']),
      tracking: (map['tracking'] ?? 'none').toString(),
      qtyAvailable: map['qty_available'] != null ? asDouble(map['qty_available']) : null,
      distributorQtyAvailable: map['distributor_qty_available'] != null ? asDouble(map['distributor_qty_available']) : null,
    );
  }
}

class DeliveryOrderSummary {
  const DeliveryOrderSummary({
    required this.id,
    required this.name,
    required this.state,
    this.stateLabel,
    this.scheduledDate,
  });

  final int id;
  final String name;
  final String state;
  final String? stateLabel;
  final String? scheduledDate;

  factory DeliveryOrderSummary.fromMap(Map<String, dynamic> map) {
    return DeliveryOrderSummary(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      stateLabel: asNullableString(map['state_label']),
      scheduledDate: asNullableString(map['scheduled_date']),
    );
  }
}

String formatQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

