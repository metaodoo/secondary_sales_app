import 'package:secondary_sales/core/util/parse.dart';
import 'virtual_location.dart';

class VirtualTransferPrepare {
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? distributor;
  final Map<String, dynamic>? sourceLocation;
  final List<VirtualLocation> destinationLocations;

  VirtualTransferPrepare({
    this.employee,
    this.distributor,
    this.sourceLocation,
    required this.destinationLocations,
  });

  factory VirtualTransferPrepare.fromMap(Map<String, dynamic> map) {
    final destinations = map['destination_locations'];
    return VirtualTransferPrepare(
      employee: asMap(map['employee']),
      distributor: asMap(map['distributor']),
      sourceLocation: asMap(map['source_location']),
      destinationLocations: destinations is List
          ? destinations
                .map((item) => VirtualLocation.fromMap(asMap(item)))
                .toList()
          : [],
    );
  }
}

class TransferProduct {
  final int id;
  final String name;
  final String? code;
  final String tracking;
  final double availableQty;
  final Map<String, dynamic>? uom;

  TransferProduct({
    required this.id,
    required this.name,
    this.code,
    required this.tracking,
    required this.availableQty,
    this.uom,
  });

  factory TransferProduct.fromMap(Map<String, dynamic> map) {
    return TransferProduct(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      code: map['default_code'],
      tracking: map['tracking'] ?? 'none',
      availableQty: asDouble(map['available_qty']),
      uom: asMapOrNull(map['uom']),
    );
  }

  String get uomName => uom?['name']?.toString() ?? 'Unit';
  bool get requiresLots => tracking != 'none';
}

class TransferLot {
  final int lotId;
  final String lotName;
  final double availableQty;
  final double scrapQty;
  final double damagedQualityQty;

  TransferLot({
    required this.lotId,
    required this.lotName,
    required this.availableQty,
    this.scrapQty = 0.0,
    this.damagedQualityQty = 0.0,
  });

  factory TransferLot.fromMap(Map<String, dynamic> map) {
    return TransferLot(
      lotId: asInt(map['lot_id']),
      lotName: map['lot_name'] ?? '',
      availableQty: asDouble(map['available_qty']),
      scrapQty: asDouble(map['scrap_qty']),
      damagedQualityQty: asDouble(map['damaged_quality_qty']),
    );
  }
}

class VirtualTransferLineEntry {
  VirtualTransferLineEntry({
    required this.product,
    required this.quantity,
    this.soQty,
    this.qcQty,
    this.freshQty,
    this.scrapQty,
    this.damagedQualityQty,
    List<TransferLotInput>? lotLines,
  }) : lotLines = lotLines ?? [];

  final TransferProduct product;
  double quantity;
  double? soQty;
  double? qcQty;
  double? freshQty;
  double? scrapQty;
  double? damagedQualityQty;
  final List<TransferLotInput> lotLines;
}

class TransferLotInput {
  TransferLotInput({
    this.lot,
    this.quantity = 0,
    this.soQty,
    this.qcQty,
    this.freshQty,
    this.scrapQty,
    this.damagedQualityQty,
  });

  TransferLot? lot;
  double quantity;
  double? soQty;
  double? qcQty;
  double? freshQty;
  double? scrapQty;
  double? damagedQualityQty;
}

class VirtualTransfer {
  final int id;
  final String name;
  final String state;
  final String? vanOperationType;
  final String? generatedTransferType;
  final String? ssTransferCategory;
  final DateTime? scheduledDate;
  final Map<String, dynamic>? distributor;
  final Map<String, dynamic>? sourceLocation;
  final Map<String, dynamic>? destinationLocation;
  final List<VirtualTransfer> generatedTransfers;
  final List<VirtualTransferLine> lines;

  VirtualTransfer({
    required this.id,
    required this.name,
    required this.state,
    this.vanOperationType,
    this.generatedTransferType,
    this.ssTransferCategory,
    this.scheduledDate,
    this.distributor,
    this.sourceLocation,
    this.destinationLocation,
    required this.generatedTransfers,
    required this.lines,
  });

  factory VirtualTransfer.fromMap(Map<String, dynamic> map) {
    final rawGeneratedTransfers = map['generated_transfers'];
    final rawLines = map['lines'];
    return VirtualTransfer(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      state: map['state'] ?? '',
      vanOperationType: map['van_operation_type'],
      generatedTransferType: map['generated_transfer_type'],
      ssTransferCategory: map['ss_transfer_category'],
      scheduledDate: asDateTime(map['scheduled_date']),
      distributor: asMapOrNull(map['distributor']),
      sourceLocation: asMapOrNull(map['source_location']),
      destinationLocation: asMapOrNull(map['destination_location']),
      generatedTransfers: rawGeneratedTransfers is List
          ? rawGeneratedTransfers
                .map((item) => VirtualTransfer.fromMap(asMap(item)))
                .toList()
          : [],
      lines: rawLines is List
          ? rawLines
                .map((item) => VirtualTransferLine.fromMap(asMap(item)))
                .toList()
          : [],
    );
  }

  bool get canValidate => !['done', 'cancel'].contains(state);
  bool get canCancel => !['done', 'cancel'].contains(state);
}

class VirtualTransferLine {
  final int moveId;
  final String state;
  final Map<String, dynamic>? product;
  final double demandQty;
  final double quantity;
  final double soQty;
  final double warehouseQty;
  final double scrapQty;
  final double damagedQualityQty;
  final Map<String, dynamic>? uom;
  final List<Map<String, dynamic>> lotLines;

  VirtualTransferLine({
    required this.moveId,
    required this.state,
    this.product,
    required this.demandQty,
    required this.quantity,
    this.soQty = 0,
    this.warehouseQty = 0,
    required this.scrapQty,
    this.damagedQualityQty = 0,
    this.uom,
    required this.lotLines,
  });

  factory VirtualTransferLine.fromMap(Map<String, dynamic> map) {
    final rawLots = map['lot_lines'];
    return VirtualTransferLine(
      moveId: asInt(map['move_id']),
      state: map['state'] ?? '',
      product: asMapOrNull(map['product']),
      demandQty: asDouble(map['demand_qty']),
      quantity: asDouble(map['quantity']),
      soQty: asDouble(map['so_qty']),
      warehouseQty: asDouble(map['warehouse_qty']),
      scrapQty: asDouble(map['scrap_qty']),
      damagedQualityQty: asDouble(map['damaged_quality_qty']),
      uom: asMapOrNull(map['uom']),
      lotLines: rawLots is List ? rawLots.map(asMap).toList() : [],
    );
  }

  double get freshQty {
    final fresh = quantity - scrapQty - damagedQualityQty;
    return fresh < 0 ? 0 : fresh;
  }

  String get productName => product?['name']?.toString() ?? '-';
  String get uomName => uom?['name']?.toString() ?? 'Unit';
  bool get requiresLots => product?['tracking'] != 'none' && product?['tracking'] != null;
}

