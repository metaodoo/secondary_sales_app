import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/util/parse.dart';
import 'virtual_location.dart';

class TransferAttachment {
  final int id;
  final String name;
  final String mimetype;
  final String url;
  final bool isImage;

  TransferAttachment({
    required this.id,
    required this.name,
    required this.mimetype,
    required this.url,
    required this.isImage,
  });

  factory TransferAttachment.fromMap(Map<String, dynamic> map) {
    final rawUrl = (map['url'] ?? '').toString();
    final fullUrl = rawUrl.startsWith('http')
        ? rawUrl
        : '${AppConstants.baseUrl}$rawUrl';
    final mime = (map['mimetype'] ?? '').toString();
    return TransferAttachment(
      id: asInt(map['id']),
      name: (map['name'] ?? 'Attachment').toString(),
      mimetype: mime,
      url: fullUrl,
      isImage: asBool(map['is_image']) ||
          mime.startsWith('image') ||
          rawUrl.toLowerCase().contains('.jpg') ||
          rawUrl.toLowerCase().contains('.jpeg') ||
          rawUrl.toLowerCase().contains('.png') ||
          rawUrl.toLowerCase().contains('.webp'),
    );
  }
}

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
    this.wNonsaleableQty,
    this.qcSaleableQty,
    this.qcNonsaleableQty,
    this.wQcQty,
    this.actualQcQty,
    this.freshQty,
    this.scrapQty,
    this.damagedQualityQty,
    List<TransferLotInput>? lotLines,
  }) : lotLines = lotLines ?? [];

  final TransferProduct product;
  double quantity;
  double? soQty;

  /// Warehouse **saleable** quantity — wire name `warehouse_qty`.
  ///
  /// Named `qcQty` for historical reasons; it has never been a QC quantity.
  /// The sales-operation QC decision lives in [qcSaleableQty] /
  /// [qcNonsaleableQty].
  double? qcQty;

  /// Warehouse non-saleable quantity — wire name `w_nonsaleable_qty`.
  double? wNonsaleableQty;

  /// Sales-operation saleable decision — wire name `qc_saleable_qty`.
  /// On a fresh return's transit leg this is what actually moves to warehouse
  /// stock; the app no longer sends `quantity` for those pickings.
  double? qcSaleableQty;

  /// Sales-operation non-saleable decision — wire name `qc_nonsaleable_qty`.
  ///
  /// On a fresh return this drives the auto-generated write-off to the company
  /// scrap location. On a damaged or quality return there is no write-off, so
  /// it is added to [actualQcQty] and the total is what moves.
  double? qcNonsaleableQty;

  /// Damaged and quality returns only — wire name `w_qc_qty`.
  ///
  /// The coordinator's count. Separate from [qcQty] because that one means
  /// *saleable*, and nothing in a scrap return is.
  double? wQcQty;

  /// Damaged and quality returns only — wire name `actual_qc_qty`.
  /// Added to [qcNonsaleableQty] to give the quantity the transit leg moves.
  double? actualQcQty;

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
    this.wNonsaleableQty,
    this.qcSaleableQty,
    this.qcNonsaleableQty,
    this.wQcQty,
    this.actualQcQty,
    this.freshQty,
    this.scrapQty,
    this.damagedQualityQty,
  });

  TransferLot? lot;
  double quantity;
  double? soQty;

  /// Warehouse **saleable** quantity — wire name `warehouse_qty`. See
  /// [VirtualTransferLineEntry.qcQty] for why the name says `qc`.
  double? qcQty;
  double? wNonsaleableQty;
  double? qcSaleableQty;
  double? qcNonsaleableQty;

  /// Scrap flavours only — wire names `w_qc_qty` and `actual_qc_qty`.
  double? wQcQty;
  double? actualQcQty;
  double? freshQty;
  double? scrapQty;
  double? damagedQualityQty;
}

/// The four QC columns a picking uses, in display order, as (label, wire name).
///
/// Only the first and third differ between modes: nothing on a damaged or
/// quality return is saleable, so those carry their own pair rather than
/// reusing the fresh ones. Served by the backend as `qc_mode`.
List<(String, String)> qcColumnsFor(String? qcMode) => qcMode == 'scrap_sum'
    ? const [
        ('Warehouse QC', 'w_qc_qty'),
        ('Warehouse Non-saleable', 'w_nonsaleable_qty'),
        ('Actual QC', 'actual_qc_qty'),
        ('QC Non-saleable', 'qc_nonsaleable_qty'),
      ]
    : const [
        ('Warehouse Saleable', 'warehouse_qty'),
        ('Warehouse Non-saleable', 'w_nonsaleable_qty'),
        ('QC Saleable', 'qc_saleable_qty'),
        ('QC Non-saleable', 'qc_nonsaleable_qty'),
      ];

/// Read and write the SS quantity columns by wire name.
///
/// Both return screens drive their forms from [qcColumnsFor], so neither needs
/// to know which Dart field backs which column.
extension SsQtyAccess on VirtualTransferLineEntry {
  double? ssQty(String field) => switch (field) {
    'warehouse_qty' => qcQty,
    'w_nonsaleable_qty' => wNonsaleableQty,
    'qc_saleable_qty' => qcSaleableQty,
    'qc_nonsaleable_qty' => qcNonsaleableQty,
    'w_qc_qty' => wQcQty,
    'actual_qc_qty' => actualQcQty,
    'so_qty' => soQty,
    _ => null,
  };

  void setSsQty(String field, double value) {
    switch (field) {
      case 'warehouse_qty':
        qcQty = value;
      case 'w_nonsaleable_qty':
        wNonsaleableQty = value;
      case 'qc_saleable_qty':
        qcSaleableQty = value;
      case 'qc_nonsaleable_qty':
        qcNonsaleableQty = value;
      case 'w_qc_qty':
        wQcQty = value;
      case 'actual_qc_qty':
        actualQcQty = value;
      case 'so_qty':
        soQty = value;
    }
  }
}

extension SsLotQtyAccess on TransferLotInput {
  double? ssQty(String field) => switch (field) {
    'warehouse_qty' => qcQty,
    'w_nonsaleable_qty' => wNonsaleableQty,
    'qc_saleable_qty' => qcSaleableQty,
    'qc_nonsaleable_qty' => qcNonsaleableQty,
    'w_qc_qty' => wQcQty,
    'actual_qc_qty' => actualQcQty,
    'so_qty' => soQty,
    _ => null,
  };

  void setSsQty(String field, double value) {
    switch (field) {
      case 'warehouse_qty':
        qcQty = value;
      case 'w_nonsaleable_qty':
        wNonsaleableQty = value;
      case 'qc_saleable_qty':
        qcSaleableQty = value;
      case 'qc_nonsaleable_qty':
        qcNonsaleableQty = value;
      case 'w_qc_qty':
        wQcQty = value;
      case 'actual_qc_qty':
        actualQcQty = value;
      case 'so_qty':
        soQty = value;
    }
  }
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
  final List<TransferAttachment> attachments;
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
    required this.attachments,
    required this.generatedTransfers,
    required this.lines,
  });

  factory VirtualTransfer.fromMap(Map<String, dynamic> map) {
    final rawAttachments = map['attachments'];
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
      attachments: rawAttachments is List
          ? rawAttachments
                .map((item) => TransferAttachment.fromMap(asMap(item)))
                .toList()
          : [],
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
  bool get requiresLots =>
      product?['tracking'] != 'none' && product?['tracking'] != null;
}
