import 'package:secondary_sales/core/util/parse.dart';

/// List-row summary for a return or scrap delivery. Both are stock pickings
/// with the same summary shape, so the returns and scraps list screens share
/// this model.
class ReturnScrapSummary {
  const ReturnScrapSummary({
    required this.id,
    required this.name,
    required this.state,
    this.origin,
    this.scheduledDate,
  });

  final int id;
  final String name;
  final String state;
  final String? origin;
  final String? scheduledDate;

  factory ReturnScrapSummary.fromMap(Map<String, dynamic> map) {
    return ReturnScrapSummary(
      id: asInt(map['id']),
      name: asNullableString(map['name']) ?? '',
      state: asNullableString(map['state']) ?? '',
      origin: asNullableString(map['origin']),
      scheduledDate: asNullableString(map['scheduled_date']),
    );
  }
}
