import 'package:secondary_sales/core/util/parse.dart';

/// List-row summary for a return or scrap delivery. Both are stock pickings
/// with the same summary shape, so the returns and scraps list screens share
/// this model.
class ReturnScrapSummary {
  const ReturnScrapSummary({
    required this.id,
    required this.name,
    required this.state,
    this.returnReciptStatus,
    this.origin,
    this.scheduledDate,
    this.returnBookNumber,
    this.returnBookPage,
  });

  final int id;
  final String name;
  final String state;
  final String? returnReciptStatus;
  final String? origin;
  final DateTime? scheduledDate;
  final String? returnBookNumber;
  final String? returnBookPage;

  factory ReturnScrapSummary.fromMap(Map<String, dynamic> map) {
    return ReturnScrapSummary(
      id: asInt(map['id']),
      name: asNullableString(map['name']) ?? '',
      state: asNullableString(map['state']) ?? '',
      returnReciptStatus: asNullableString(map['return_recipt_status']),
      origin: asNullableString(map['origin']),
      scheduledDate: asDateTime(map['scheduled_date']),
      returnBookNumber: asNullableString(map['return_book_number']),
      returnBookPage: asNullableString(map['return_book_page']),
    );
  }
}
