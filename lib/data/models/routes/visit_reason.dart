import 'package:secondary_sales/core/util/parse.dart';

class VisitReason {
  final int id;
  final String name;
  final bool isSale;

  VisitReason({required this.id, required this.name, this.isSale = false});

  factory VisitReason.fromMap(Map<String, dynamic> map) {
    return VisitReason(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      isSale: map['is_sale'] == true,
    );
  }
}

class VisitReasonSelection {
  final int reasonId;
  final String? reasonName;
  final String? notes;
  final double? saleAmount;

  VisitReasonSelection({
    required this.reasonId,
    this.reasonName,
    this.notes,
    this.saleAmount,
  });
}
