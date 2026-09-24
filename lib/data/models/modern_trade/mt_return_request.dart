import 'package:secondary_sales/core/util/parse.dart';

class MtReturnRequest {
  final int id;
  final String name;
  final String? date;
  final String businessType;
  final String returnBucket;
  final String returnBucketDisplay;
  final String state;
  final String stateDisplay;
  final int? partnerId;
  final String? partnerName;
  final String? ssCode;
  final int? zoneId;
  final String? zoneName;
  final int? warehouseId;
  final String? warehouseName;
  final int? returnScrapLocationId;
  final String? returnScrapLocationName;
  final int? locationId;
  final String? locationName;
  final int? locationDestId;
  final String? locationDestName;
  final int totalLines;
  final double totalSaleableQty;
  final double totalNonSaleableQty;
  final double totalQualityQty;
  final double totalQty;
  final int pickingCount;
  final MtAllowedActions allowedActions;
  final List<MtReturnRequestLine> lines;
  final List<MtReturnTransfer> transfers;

  MtReturnRequest({
    required this.id,
    required this.name,
    this.date,
    this.businessType = 'mt',
    required this.returnBucket,
    required this.returnBucketDisplay,
    required this.state,
    required this.stateDisplay,
    this.partnerId,
    this.partnerName,
    this.ssCode,
    this.zoneId,
    this.zoneName,
    this.warehouseId,
    this.warehouseName,
    this.returnScrapLocationId,
    this.returnScrapLocationName,
    this.locationId,
    this.locationName,
    this.locationDestId,
    this.locationDestName,
    this.totalLines = 0,
    this.totalSaleableQty = 0.0,
    this.totalNonSaleableQty = 0.0,
    this.totalQualityQty = 0.0,
    this.totalQty = 0.0,
    this.pickingCount = 0,
    required this.allowedActions,
    this.lines = const [],
    this.transfers = const [],
  });

  bool get isSaleable => returnBucket == 'saleable';
  bool get isNonSaleable => returnBucket == 'non_saleable';
  bool get isConfirmed => state.toLowerCase() == 'confirmed';
  bool get isDraft => state.toLowerCase() == 'kao';

  factory MtReturnRequest.fromMap(Map<String, dynamic> map) {
    final partner = map['partner'] is Map ? map['partner'] as Map : null;
    final zone = map['zone'] is Map ? map['zone'] as Map : null;
    final wh = map['warehouse'] is Map ? map['warehouse'] as Map : null;
    final scrapLoc = map['return_scrap_location'] is Map ? map['return_scrap_location'] as Map : null;
    final loc = map['location'] is Map ? map['location'] as Map : null;
    final locDest = map['location_dest'] is Map ? map['location_dest'] as Map : null;
    final actMap = map['allowed_actions'] is Map ? map['allowed_actions'] as Map<String, dynamic> : <String, dynamic>{};
    final rawLines = map['lines'] as List? ?? [];
    final rawTransfers = map['transfers'] as List? ?? [];

    return MtReturnRequest(
      id: asInt(map['id']),
      name: map['name']?.toString() ?? '',
      date: map['date']?.toString(),
      businessType: map['business_type']?.toString() ?? 'mt',
      returnBucket: map['return_bucket']?.toString() ?? 'saleable',
      returnBucketDisplay: map['return_bucket_display']?.toString() ?? map['return_bucket']?.toString() ?? '',
      state: map['state']?.toString() ?? 'kao',
      stateDisplay: map['state_display']?.toString() ?? map['state']?.toString() ?? '',
      partnerId: partner != null ? asInt(partner['id']) : null,
      partnerName: partner?['name']?.toString(),
      ssCode: map['ss_code']?.toString() ?? partner?['ss_code']?.toString(),
      zoneId: zone != null ? asInt(zone['id']) : null,
      zoneName: zone?['name']?.toString(),
      warehouseId: wh != null ? asInt(wh['id']) : null,
      warehouseName: wh?['name']?.toString(),
      returnScrapLocationId: scrapLoc != null ? asInt(scrapLoc['id']) : null,
      returnScrapLocationName: scrapLoc?['name']?.toString(),
      locationId: loc != null ? asInt(loc['id']) : null,
      locationName: loc?['name']?.toString(),
      locationDestId: locDest != null ? asInt(locDest['id']) : null,
      locationDestName: locDest?['name']?.toString(),
      totalLines: asInt(map['total_lines']),
      totalSaleableQty: asDouble(map['total_saleable_qty']),
      totalNonSaleableQty: asDouble(map['total_non_saleable_qty']),
      totalQualityQty: asDouble(map['total_quality_qty']),
      totalQty: asDouble(map['total_qty']),
      pickingCount: asInt(map['picking_count']),
      allowedActions: MtAllowedActions.fromMap(actMap),
      lines: rawLines
          .map((l) => MtReturnRequestLine.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
      transfers: rawTransfers
          .map((t) => MtReturnTransfer.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }
}

class MtAllowedActions {
  final bool canEdit;
  final bool canSubmit;
  final bool canConfirm;
  final bool canReset;
  final String? nextState;
  final String? nextAction;
  final String? nextActionLabel;

  MtAllowedActions({
    this.canEdit = false,
    this.canSubmit = false,
    this.canConfirm = false,
    this.canReset = false,
    this.nextState,
    this.nextAction,
    this.nextActionLabel,
  });

  factory MtAllowedActions.fromMap(Map<String, dynamic> map) {
    return MtAllowedActions(
      canEdit: map['can_edit'] == true,
      canSubmit: map['can_submit'] == true,
      canConfirm: map['can_confirm'] == true,
      canReset: map['can_reset'] == true,
      nextState: map['next_state']?.toString(),
      nextAction: map['next_action']?.toString(),
      nextActionLabel: map['next_action_label']?.toString(),
    );
  }
}

class MtReturnRequestLine {
  final int id;
  final int productId;
  final String productName;
  final String? defaultCode;
  final String? barcode;
  final int? uomId;
  final String uomName;
  final int? lotId;
  final String? lotName;
  final String? expirationDate;
  double saleableQty;
  double nonSaleableQty;
  double qualityQty;
  final double totalQty;
  final List<MtReturnLineUserHistory> userHistory;

  MtReturnRequestLine({
    required this.id,
    required this.productId,
    required this.productName,
    this.defaultCode,
    this.barcode,
    this.uomId,
    this.uomName = 'Unit',
    this.lotId,
    this.lotName,
    this.expirationDate,
    this.saleableQty = 0.0,
    this.nonSaleableQty = 0.0,
    this.qualityQty = 0.0,
    this.totalQty = 0.0,
    this.userHistory = const [],
  });

  factory MtReturnRequestLine.fromMap(Map<String, dynamic> map) {
    final prod = map['product'] is Map ? map['product'] as Map : null;
    final uom = map['uom'] is Map ? map['uom'] as Map : null;
    final lot = map['lot'] is Map ? map['lot'] as Map : null;
    final rawHist = map['user_history'] as List? ?? [];

    return MtReturnRequestLine(
      id: asInt(map['id']),
      productId: prod != null ? asInt(prod['id']) : asInt(map['product_id']),
      productName: prod?['name']?.toString() ?? map['product_name']?.toString() ?? '',
      defaultCode: prod?['default_code']?.toString(),
      barcode: prod?['barcode']?.toString(),
      uomId: uom != null ? asInt(uom['id']) : null,
      uomName: uom?['name']?.toString() ?? 'Unit',
      lotId: lot != null ? asInt(lot['id']) : null,
      lotName: lot?['name']?.toString(),
      expirationDate: lot?['expiration_date']?.toString(),
      saleableQty: asDouble(map['saleable_qty']),
      nonSaleableQty: asDouble(map['non_saleable_qty']),
      qualityQty: asDouble(map['quality_qty']),
      totalQty: asDouble(map['total_qty']),
      userHistory: rawHist
          .map((h) => MtReturnLineUserHistory.fromMap(Map<String, dynamic>.from(h as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'id': id,
      'saleable_qty': saleableQty,
      'non_saleable_qty': nonSaleableQty,
      'quality_qty': qualityQty,
      if (lotId != null) 'lot_id': lotId,
    };
  }
}

class MtReturnLineUserHistory {
  final int id;
  final int? userId;
  final String userName;
  final String? createDate;
  final double saleableQty;
  final double nonSaleableQty;
  final double qualityQty;
  final double totalQty;

  MtReturnLineUserHistory({
    required this.id,
    this.userId,
    this.userName = '',
    this.createDate,
    this.saleableQty = 0.0,
    this.nonSaleableQty = 0.0,
    this.qualityQty = 0.0,
    this.totalQty = 0.0,
  });

  factory MtReturnLineUserHistory.fromMap(Map<String, dynamic> map) {
    final user = map['user'] is Map ? map['user'] as Map : null;
    return MtReturnLineUserHistory(
      id: asInt(map['id']),
      userId: user != null ? asInt(user['id']) : null,
      userName: user?['name']?.toString() ?? '',
      createDate: map['create_date']?.toString(),
      saleableQty: asDouble(map['saleable_qty']),
      nonSaleableQty: asDouble(map['non_saleable_qty']),
      qualityQty: asDouble(map['quality_qty']),
      totalQty: asDouble(map['total_qty']),
    );
  }
}

class MtReturnTransfer {
  final int id;
  final String name;
  final String? origin;
  final int? pickingTypeId;
  final String pickingTypeName;
  final String pickingTypeCode;
  final String? locationName;
  final String? locationDestName;
  final String state;
  final String stateDisplay;
  final bool isParent;
  final int? parentTransferId;
  final String? parentTransferName;
  final List<MtTransferMove> moves;

  bool get isReceipt =>
      pickingTypeCode.toLowerCase() == 'incoming' ||
      (pickingTypeCode.isEmpty &&
          (pickingTypeName.toLowerCase().contains('receipt') ||
              pickingTypeName.toLowerCase().contains('incoming') ||
              pickingTypeName.toLowerCase().contains('scrap')));

  bool get isDelivery =>
      pickingTypeCode.toLowerCase() == 'outgoing' ||
      (pickingTypeCode.isEmpty &&
          (pickingTypeName.toLowerCase().contains('delivery') ||
              pickingTypeName.toLowerCase().contains('dispatch') ||
              pickingTypeName.toLowerCase().contains('out')));

  MtReturnTransfer({
    required this.id,
    required this.name,
    this.origin,
    this.pickingTypeId,
    this.pickingTypeName = '',
    this.pickingTypeCode = '',
    this.locationName,
    this.locationDestName,
    required this.state,
    required this.stateDisplay,
    this.isParent = true,
    this.parentTransferId,
    this.parentTransferName,
    this.moves = const [],
  });

  factory MtReturnTransfer.fromMap(Map<String, dynamic> map) {
    final pType = map['picking_type'] is Map ? map['picking_type'] as Map : null;
    final loc = map['location'] is Map ? map['location'] as Map : null;
    final locDest = map['location_dest'] is Map ? map['location_dest'] as Map : null;
    final parent = map['parent_transfer'] is Map ? map['parent_transfer'] as Map : null;
    final rawMoves = map['moves'] as List? ?? [];

    return MtReturnTransfer(
      id: asInt(map['id']),
      name: map['name']?.toString() ?? '',
      origin: map['origin']?.toString(),
      pickingTypeId: pType != null ? asInt(pType['id']) : null,
      pickingTypeName: pType?['name']?.toString() ?? '',
      pickingTypeCode: pType?['code']?.toString() ?? '',
      locationName: loc?['name']?.toString(),
      locationDestName: locDest?['name']?.toString(),
      state: map['state']?.toString() ?? 'draft',
      stateDisplay: map['state_display']?.toString() ?? map['state']?.toString() ?? '',
      isParent: map['is_parent'] == true,
      parentTransferId: parent != null ? asInt(parent['id']) : null,
      parentTransferName: parent?['name']?.toString(),
      moves: rawMoves
          .map((m) => MtTransferMove.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
    );
  }
}

class MtTransferMove {
  final int id;
  final int productId;
  final String productName;
  final double demandQty;
  final double quantity;
  final String uomName;
  final String state;
  final List<MtTransferMoveLine> moveLines;

  MtTransferMove({
    required this.id,
    required this.productId,
    required this.productName,
    this.demandQty = 0.0,
    this.quantity = 0.0,
    this.uomName = 'Unit',
    required this.state,
    this.moveLines = const [],
  });

  factory MtTransferMove.fromMap(Map<String, dynamic> map) {
    final prod = map['product'] is Map ? map['product'] as Map : null;
    final uom = map['uom'] is Map ? map['uom'] as Map : null;
    final rawMoveLines = map['move_lines'] as List? ?? [];

    return MtTransferMove(
      id: asInt(map['id']),
      productId: prod != null ? asInt(prod['id']) : 0,
      productName: prod?['name']?.toString() ?? '',
      demandQty: asDouble(map['demand_qty']),
      quantity: asDouble(map['quantity']),
      uomName: uom?['name']?.toString() ?? 'Unit',
      state: map['state']?.toString() ?? 'draft',
      moveLines: rawMoveLines
          .map((ml) => MtTransferMoveLine.fromMap(Map<String, dynamic>.from(ml as Map)))
          .toList(),
    );
  }
}

class MtTransferMoveLine {
  final int id;
  final int? lotId;
  final String? lotName;
  final double quantity;
  final String uomName;

  MtTransferMoveLine({
    required this.id,
    this.lotId,
    this.lotName,
    this.quantity = 0.0,
    this.uomName = 'Unit',
  });

  factory MtTransferMoveLine.fromMap(Map<String, dynamic> map) {
    final lot = map['lot'] is Map ? map['lot'] as Map : null;
    final uom = map['uom'] is Map ? map['uom'] as Map : null;
    return MtTransferMoveLine(
      id: asInt(map['id']),
      lotId: lot != null ? asInt(lot['id']) : null,
      lotName: lot?['name']?.toString(),
      quantity: asDouble(map['quantity']),
      uomName: uom?['name']?.toString() ?? 'Unit',
    );
  }
}
