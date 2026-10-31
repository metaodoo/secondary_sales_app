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
  final double freshQty;
  final double qcQty;
  final double damageQty;
  final double priceUnit;
  final Map<String, dynamic>? uom;

  TransferProduct({
    required this.id,
    required this.name,
    this.code,
    required this.tracking,
    required this.availableQty,
    this.freshQty = 0.0,
    this.qcQty = 0.0,
    this.damageQty = 0.0,
    this.priceUnit = 0.0,
    this.uom,
  });

  factory TransferProduct.fromMap(Map<String, dynamic> map) {
    final stockByLoc = asMapOrNull(map['stock_by_location']);
    final fresh = map['fresh_qty'] != null
        ? asDouble(map['fresh_qty'])
        : asDouble(stockByLoc?['Fresh']);
    final qc = map['qc_qty'] != null
        ? asDouble(map['qc_qty'])
        : asDouble(stockByLoc?['QC']);
    final damage = map['damage_qty'] != null
        ? asDouble(map['damage_qty'])
        : asDouble(stockByLoc?['Damage']);
    final total = map['available_qty'] != null
        ? asDouble(map['available_qty'])
        : (fresh + qc + damage);
    final pUnit = asDouble(map['list_price'] ?? map['price_unit'] ?? map['price']);

    return TransferProduct(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      code: map['default_code'],
      tracking: map['tracking'] ?? 'none',
      availableQty: total,
      freshQty: fresh,
      qcQty: qc,
      damageQty: damage,
      priceUnit: pUnit,
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
    this.qcTeamNonsaleableQty,
    this.qcTeamQcQty,
    this.actualQcQty,
    this.freshQty,
    this.scrapQty,
    this.damagedQualityQty,
    this.soRemark,
    this.logisticRemark,
    this.qcRemark,
    this.salesopsRemark,
    List<TransferLotInput>? lotLines,
  }) : lotLines = lotLines ?? [];

  final TransferProduct product;
  double quantity;
  double? soQty;

  /// Warehouse **saleable** quantity — wire name `warehouse_qty` (Logistic SR).
  ///
  /// Named `qcQty` for historical reasons; it has never been a QC quantity.
  /// The sales-operation QC decision lives in [qcSaleableQty] /
  /// [qcNonsaleableQty].
  double? qcQty;

  /// Warehouse non-saleable quantity — wire name `w_nonsaleable_qty` (Logistic Non-SR).
  double? wNonsaleableQty;

  /// Sales-operation saleable decision — wire name `qc_saleable_qty` (Sales Ops SR).
  /// On a fresh return's transit leg this is what actually moves to warehouse
  /// stock; the app no longer sends `quantity` for those pickings.
  double? qcSaleableQty;

  /// Sales-operation non-saleable decision — wire name `qc_nonsaleable_qty` (Sales Ops Non-SR).
  ///
  /// On a fresh return this drives the auto-generated write-off to the company
  /// scrap location. On a damaged or quality return there is no write-off, so
  /// it is added to [actualQcQty] and the total is what moves.
  double? qcNonsaleableQty;

  /// Damaged and quality returns only — wire name `w_qc_qty` (Logistic QR).
  ///
  /// The coordinator's count. Separate from [qcQty] because that one means
  /// *saleable*, and nothing in a scrap return is.
  double? wQcQty;

  /// Quality Control evaluation non-saleable quantity — wire name `qc_team_nonsaleable_qty` (QC- Non-SR).
  double? qcTeamNonsaleableQty;

  /// Quality Control evaluation quality quantity — wire name `qc_team_qc_qty` (QC- QR).
  double? qcTeamQcQty;

  /// Damaged and quality returns only — wire name `actual_qc_qty` (Sales Ops QR).
  /// Added to [qcNonsaleableQty] to give the quantity the transit leg moves.
  double? actualQcQty;

  double? freshQty;
  double? scrapQty;
  double? damagedQualityQty;
  String? soRemark;
  String? logisticRemark;
  String? qcRemark;
  String? salesopsRemark;
  final List<TransferLotInput> lotLines;

  double get priceUnit => product.priceUnit;
  /// Price times the quantity the person editing the line enters: the SO
  /// figure for sales operation ([bySoQty]), the warehouse figure for the
  /// warehouse ([byWarehouseQty]), otherwise the quantity -- the same choice
  /// the return and scrap screens make when a lot quantity is typed. A
  /// lot-tracked line's figures are entered on its lots and only copied to
  /// the line on save, so its lots are summed.
  ///
  /// A saved line carries 0.0, not null, for the stages nobody has filled in
  /// yet, so the figure is chosen by role rather than by the first non-null
  /// one -- otherwise an unfilled SO figure would zero every amount.
  double amountFor({bool bySoQty = false, bool byWarehouseQty = false}) {
    double entered(double? so, double? warehouse, double qty) =>
        bySoQty ? (so ?? qty) : (byWarehouseQty ? (warehouse ?? qty) : qty);
    final qty = lotLines.isEmpty
        ? entered(soQty, qcQty, quantity)
        : lotLines.fold<double>(
            0,
            (sum, l) => sum + entered(l.soQty, l.qcQty, l.quantity),
          );
    return priceUnit * qty;
  }
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
    this.qcTeamNonsaleableQty,
    this.qcTeamQcQty,
    this.actualQcQty,
    this.freshQty,
    this.scrapQty,
    this.damagedQualityQty,
    this.soRemark,
    this.logisticRemark,
    this.qcRemark,
    this.salesopsRemark,
  });

  TransferLot? lot;
  double quantity;
  double? soQty;

  /// Warehouse **saleable** quantity — wire name `warehouse_qty` (Logistic SR). See
  /// [VirtualTransferLineEntry.qcQty] for why the name says `qc`.
  double? qcQty;
  double? wNonsaleableQty;
  double? qcSaleableQty;
  double? qcNonsaleableQty;

  /// Scrap flavours only — wire names `w_qc_qty`, `qc_team_nonsaleable_qty`, `qc_team_qc_qty`, and `actual_qc_qty`.
  double? wQcQty;
  double? qcTeamNonsaleableQty;
  double? qcTeamQcQty;
  double? actualQcQty;
  double? freshQty;
  double? scrapQty;
  double? damagedQualityQty;
  String? soRemark;
  String? logisticRemark;
  String? qcRemark;
  String? salesopsRemark;
}

/// The QC columns a picking uses, in display order, as (label, wire name) matching Option B.
///
/// Served by the backend as `qc_mode`.
List<(String, String)> qcColumnsFor(String? qcMode) => qcMode == 'scrap_sum'
    ? const [
        ('Logistic Non-SR', 'w_nonsaleable_qty'),
        ('Logistic QR', 'w_qc_qty'),
        ('QC- Non-SR', 'qc_team_nonsaleable_qty'),
        ('QC- QR', 'qc_team_qc_qty'),
        ('Sales Ops Non-SR', 'qc_nonsaleable_qty'),
        ('Sales Ops QR', 'actual_qc_qty'),
      ]
    : const [
        ('Logistic SR', 'warehouse_qty'),
        ('Logistic Non-SR', 'w_nonsaleable_qty'),
        ('Sales Ops SR', 'qc_saleable_qty'),
        ('Sales Ops Non-SR', 'qc_nonsaleable_qty'),
      ];

/// Checks whether a specific QC column field is visible to the user.
bool isQcColumnVisible({
  required String field,
  required bool canViewAllReturns,
  required bool canEditWarehouseQty,
  required bool canEditQcTeamQty,
  required bool canEditEffectiveQty,
  bool canEditQcQty = false,
}) {
  if (canViewAllReturns) return true;
  if (field == 'warehouse_qty' ||
      field == 'w_nonsaleable_qty' ||
      field == 'w_qc_qty') {
    return canEditWarehouseQty || canEditQcTeamQty || canEditEffectiveQty;
  }
  if (field == 'qc_team_nonsaleable_qty' || field == 'qc_team_qc_qty') {
    return canEditQcTeamQty;
  }
  if (field == 'qc_saleable_qty' ||
      field == 'qc_nonsaleable_qty' ||
      field == 'actual_qc_qty') {
    return canEditEffectiveQty;
  }
  return true;
}

/// Checks whether a specific QC column field is editable by the user in the current stage.
bool isQcColumnEditable({
  required String field,
  required String? returnReceiptStatus,
  required bool isReadOnly,
  required bool canEditWarehouseQty,
  required bool canEditQcTeamQty,
  required bool canEditEffectiveQty,
  bool canEditQcQty = false,
}) {
  if (isReadOnly) return false;
  if (field == 'warehouse_qty' ||
      field == 'w_nonsaleable_qty' ||
      field == 'w_qc_qty') {
    final isStage = returnReceiptStatus == null ||
        returnReceiptStatus == 'warehouse_receipt';
    return canEditWarehouseQty && isStage;
  }
  if (field == 'qc_team_nonsaleable_qty' || field == 'qc_team_qc_qty') {
    final isStage = returnReceiptStatus == 'qc_receipt';
    return canEditQcTeamQty && isStage;
  }
  if (field == 'qc_saleable_qty' ||
      field == 'qc_nonsaleable_qty' ||
      field == 'actual_qc_qty') {
    final isStage = returnReceiptStatus == 'salesops_receipt' ||
        returnReceiptStatus == 'sales_operation_receipt';
    return canEditEffectiveQty && isStage;
  }
  return false;
}

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
    'qc_team_nonsaleable_qty' => qcTeamNonsaleableQty,
    'qc_team_qc_qty' => qcTeamQcQty,
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
      case 'qc_team_nonsaleable_qty':
        qcTeamNonsaleableQty = value;
      case 'qc_team_qc_qty':
        qcTeamQcQty = value;
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
    'qc_team_nonsaleable_qty' => qcTeamNonsaleableQty,
    'qc_team_qc_qty' => qcTeamQcQty,
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
      case 'qc_team_nonsaleable_qty':
        qcTeamNonsaleableQty = value;
      case 'qc_team_qc_qty':
        qcTeamQcQty = value;
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
  final double totalAmount;

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
    this.totalAmount = 0.0,
  });

  factory VirtualTransfer.fromMap(Map<String, dynamic> map) {
    final rawAttachments = map['attachments'];
    final rawGeneratedTransfers = map['generated_transfers'];
    final rawLines = map['lines'];
    final parsedLines = rawLines is List
        ? rawLines
              .map((item) => VirtualTransferLine.fromMap(asMap(item)))
              .toList()
        : <VirtualTransferLine>[];
    final totAmt = map['total_amount'] != null
        ? asDouble(map['total_amount'])
        : parsedLines.fold(0.0, (s, l) => s + l.priceSubtotal);

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
      lines: parsedLines,
      totalAmount: totAmt,
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
  final double qcTeamNonsaleableQty;
  final double qcTeamQcQty;
  final double scrapQty;
  final double damagedQualityQty;
  final double priceUnit;
  final double priceSubtotal;
  final Map<String, dynamic>? uom;
  final List<Map<String, dynamic>> lotLines;
  final String? soRemark;
  final String? logisticRemark;
  final String? qcRemark;
  final String? salesopsRemark;

  VirtualTransferLine({
    required this.moveId,
    required this.state,
    this.product,
    required this.demandQty,
    required this.quantity,
    this.soQty = 0,
    this.warehouseQty = 0,
    this.qcTeamNonsaleableQty = 0,
    this.qcTeamQcQty = 0,
    required this.scrapQty,
    this.damagedQualityQty = 0,
    this.priceUnit = 0.0,
    this.priceSubtotal = 0.0,
    this.uom,
    required this.lotLines,
    this.soRemark,
    this.logisticRemark,
    this.qcRemark,
    this.salesopsRemark,
  });

  factory VirtualTransferLine.fromMap(Map<String, dynamic> map) {
    final rawLots = map['lot_lines'];
    final prod = asMapOrNull(map['product']);
    final pUnit = asDouble(map['price_unit'] ?? prod?['list_price']);
    final qty = asDouble(map['quantity'] ?? map['so_qty'] ?? map['demand_qty']);
    final pSubtotal = map['price_subtotal'] != null
        ? asDouble(map['price_subtotal'])
        : (pUnit * qty);

    return VirtualTransferLine(
      moveId: asInt(map['move_id']),
      state: map['state'] ?? '',
      product: prod,
      demandQty: asDouble(map['demand_qty']),
      quantity: asDouble(map['quantity']),
      soQty: asDouble(map['so_qty']),
      warehouseQty: asDouble(map['warehouse_qty']),
      qcTeamNonsaleableQty: asDouble(map['qc_team_nonsaleable_qty']),
      qcTeamQcQty: asDouble(map['qc_team_qc_qty']),
      scrapQty: asDouble(map['scrap_qty']),
      damagedQualityQty: asDouble(map['damaged_quality_qty']),
      priceUnit: pUnit,
      priceSubtotal: pSubtotal,
      uom: asMapOrNull(map['uom']),
      lotLines: rawLots is List ? rawLots.map(asMap).toList() : [],
      soRemark: map['so_remark']?.toString(),
      logisticRemark: map['logistic_remark']?.toString(),
      qcRemark: map['qc_remark']?.toString(),
      salesopsRemark: map['salesops_remark']?.toString(),
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
