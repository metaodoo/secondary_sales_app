import 'package:secondary_sales/core/util/parse.dart';

class ProductCategory {
  final int id;
  final String name;
  final String? completeName;

  const ProductCategory({
    required this.id,
    required this.name,
    this.completeName,
  });

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    return ProductCategory(
      id: asInt(map['id']),
      name: map['name']?.toString() ?? '',
      completeName: map['complete_name']?.toString(),
    );
  }
}
