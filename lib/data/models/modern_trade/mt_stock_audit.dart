import 'package:secondary_sales/core/util/parse.dart';

class MtStockAudit {
  final int id;
  final String name;
  final String type;
  final String typeLabel;
  final String state;
  final DateTime? date;
  final int? employeeId;
  final String? employeeName;
  final int? outletId;
  final String? outletName;
  final String? outletCode;
  final int? visitId;
  final String notes;
  final int totalLines;
  final double totalStockCount;
  final List<MtStockAuditLine> lines;

  MtStockAudit({
    required this.id,
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.state,
    this.date,
    this.employeeId,
    this.employeeName,
    this.outletId,
    this.outletName,
    this.outletCode,
    this.visitId,
    this.notes = '',
    this.totalLines = 0,
    this.totalStockCount = 0.0,
    this.lines = const [],
  });

  bool get isConfirmed => state.toLowerCase() == 'confirm';

  factory MtStockAudit.fromMap(Map<String, dynamic> map) {
    final emp = map['employee'] is Map ? map['employee'] as Map : null;
    final out = map['outlet'] is Map ? map['outlet'] as Map : null;
    final rawLines = map['lines'] as List? ?? [];

    return MtStockAudit(
      id: asInt(map['id']),
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'opening_stock',
      typeLabel: map['type_label']?.toString() ?? map['type']?.toString() ?? '',
      state: map['state']?.toString() ?? 'draft',
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      employeeId: emp != null ? asInt(emp['id']) : null,
      employeeName: emp?['name']?.toString(),
      outletId: out != null ? asInt(out['id']) : null,
      outletName: out?['name']?.toString(),
      outletCode: out?['ss_code']?.toString(),
      visitId: map['visit_id'] != null ? asInt(map['visit_id']) : null,
      notes: map['notes']?.toString() ?? '',
      totalLines: asInt(map['total_lines']),
      totalStockCount: asDouble(map['total_stock_count']),
      lines: rawLines
          .map((l) => MtStockAuditLine.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
    );
  }
}

class MtStockAuditLine {
  final int id;
  final int productId;
  final String productName;
  final String? defaultCode;
  final String? uomName;
  final int? lotId;
  final String? lotName;
  final DateTime? expirationDate;
  final double stockCount;

  MtStockAuditLine({
    required this.id,
    required this.productId,
    required this.productName,
    this.defaultCode,
    this.uomName,
    this.lotId,
    this.lotName,
    this.expirationDate,
    required this.stockCount,
  });

  factory MtStockAuditLine.fromMap(Map<String, dynamic> map) {
    final prod = map['product'] is Map ? map['product'] as Map : null;
    final lot = map['lot'] is Map ? map['lot'] as Map : null;
    final uom = prod?['uom'] is Map ? prod!['uom'] as Map : null;

    return MtStockAuditLine(
      id: asInt(map['id']),
      productId: prod != null ? asInt(prod['id']) : 0,
      productName: prod?['name']?.toString() ?? 'Unknown Product',
      defaultCode: prod?['default_code']?.toString(),
      uomName: uom?['name']?.toString(),
      lotId: lot != null ? asInt(lot['id']) : null,
      lotName: lot?['name']?.toString(),
      expirationDate: lot?['expiration_date'] != null
          ? DateTime.tryParse(lot!['expiration_date'].toString())
          : null,
      stockCount: asDouble(map['stock_count']),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'product_id': productId,
      if (lotId != null) 'lot_id': lotId,
      'stock_count': stockCount,
    };
  }
}

class MtStockAuditProduct {
  final int id;
  final String name;
  final String? defaultCode;
  final String? tracking;
  final int? uomId;
  final String? uomName;
  final List<MtStockAuditLot> lots;

  MtStockAuditProduct({
    required this.id,
    required this.name,
    this.defaultCode,
    this.tracking,
    this.uomId,
    this.uomName,
    this.lots = const [],
  });

  bool get requiresLots => tracking == 'lot' || tracking == 'serial';

  factory MtStockAuditProduct.fromMap(Map<String, dynamic> map) {
    final uom = map['uom'] is Map ? map['uom'] as Map : null;
    final rawLots = map['lots'] as List? ?? [];

    return MtStockAuditProduct(
      id: asInt(map['id']),
      name: map['name']?.toString() ?? '',
      defaultCode: map['default_code']?.toString(),
      tracking: map['tracking']?.toString(),
      uomId: uom != null ? asInt(uom['id']) : null,
      uomName: uom?['name']?.toString(),
      lots: rawLots
          .map((l) => MtStockAuditLot.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
    );
  }
}

class MtStockAuditLot {
  final int id;
  final String name;
  final DateTime? expirationDate;

  MtStockAuditLot({
    required this.id,
    required this.name,
    this.expirationDate,
  });

  String get displayName {
    if (expirationDate != null) {
      final formatted =
          '${expirationDate!.year}-${expirationDate!.month.toString().padLeft(2, '0')}-${expirationDate!.day.toString().padLeft(2, '0')}';
      return '$name (Exp: $formatted)';
    }
    return name;
  }

  factory MtStockAuditLot.fromMap(Map<String, dynamic> map) {
    return MtStockAuditLot(
      id: asInt(map['id']),
      name: map['name']?.toString() ?? '',
      expirationDate: map['expiration_date'] != null
          ? DateTime.tryParse(map['expiration_date'].toString())
          : null,
    );
  }
}

class MtSecSaleOrder {
  final int id;
  final String name;
  final DateTime? date;
  final String state;
  final int? outletId;
  final String? outletName;
  final String? outletCode;
  final int? employeeId;
  final String? employeeName;
  final int? visitId;
  final String? visitName;
  final int totalLines;
  final double totalSoldQty;
  final List<MtSecSaleOrderLine> lines;

  MtSecSaleOrder({
    required this.id,
    required this.name,
    this.date,
    required this.state,
    this.outletId,
    this.outletName,
    this.outletCode,
    this.employeeId,
    this.employeeName,
    this.visitId,
    this.visitName,
    this.totalLines = 0,
    this.totalSoldQty = 0.0,
    this.lines = const [],
  });

  factory MtSecSaleOrder.fromMap(Map<String, dynamic> map) {
    final emp = map['employee'] is Map ? map['employee'] as Map : null;
    final out = map['outlet'] is Map ? map['outlet'] as Map : null;
    final visit = map['visit'] is Map ? map['visit'] as Map : null;
    final rawLines = map['lines'] as List? ?? [];

    return MtSecSaleOrder(
      id: asInt(map['id']),
      name: map['name']?.toString() ?? '',
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      state: map['state']?.toString() ?? 'done',
      outletId: out != null ? asInt(out['id']) : null,
      outletName: out?['name']?.toString(),
      outletCode: out?['ss_code']?.toString(),
      employeeId: emp != null ? asInt(emp['id']) : null,
      employeeName: emp?['name']?.toString(),
      visitId: visit != null ? asInt(visit['id']) : null,
      visitName: visit?['name']?.toString(),
      totalLines: asInt(map['total_lines']),
      totalSoldQty: asDouble(map['total_sold_qty']),
      lines: rawLines
          .map((l) => MtSecSaleOrderLine.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
    );
  }
}

class MtSecSaleOrderLine {
  final int id;
  final int productId;
  final String productName;
  final String? defaultCode;
  final String? uomName;
  final int? lotId;
  final String? lotName;
  final DateTime? expirationDate;
  final double openingStockQty;
  final double stockInQty;
  final double closingStockQty;
  final double soldQty;

  MtSecSaleOrderLine({
    required this.id,
    required this.productId,
    required this.productName,
    this.defaultCode,
    this.uomName,
    this.lotId,
    this.lotName,
    this.expirationDate,
    required this.openingStockQty,
    required this.stockInQty,
    required this.closingStockQty,
    required this.soldQty,
  });

  factory MtSecSaleOrderLine.fromMap(Map<String, dynamic> map) {
    final prod = map['product'] is Map ? map['product'] as Map : null;
    final lot = map['lot'] is Map ? map['lot'] as Map : null;
    final uom = prod?['uom'] is Map ? prod!['uom'] as Map : null;

    return MtSecSaleOrderLine(
      id: asInt(map['id']),
      productId: prod != null ? asInt(prod['id']) : 0,
      productName: prod?['name']?.toString() ?? 'Unknown Product',
      defaultCode: prod?['default_code']?.toString(),
      uomName: uom?['name']?.toString(),
      lotId: lot != null ? asInt(lot['id']) : null,
      lotName: lot?['name']?.toString(),
      expirationDate: lot?['expiration_date'] != null
          ? DateTime.tryParse(lot!['expiration_date'].toString())
          : null,
      openingStockQty: asDouble(map['opening_stock_qty']),
      stockInQty: asDouble(map['stock_in_qty']),
      closingStockQty: asDouble(map['closing_stock_qty']),
      soldQty: asDouble(map['sold_qty']),
    );
  }
}
