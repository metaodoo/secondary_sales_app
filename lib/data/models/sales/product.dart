import 'package:secondary_sales/core/util/parse.dart';

class Product {
  final int id;
  final String name;
  final String? code;
  final double price;
  final String? uom;
  final double? stock;
  final double? distributorStock;
  final String? nearestExpiry;

  Product({
    required this.id,
    required this.name,
    this.code,
    required this.price,
    this.uom,
    this.stock,
    this.distributorStock,
    this.nearestExpiry,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      code: map['default_code'],
      price: asDouble(map['list_price']),
      uom: map['uom_name'] ?? map['uom']?['name'] ?? 'Unit',
      stock: _nullableDouble(map['qty_available'] ?? map['stock']),
      distributorStock: _nullableDouble(map['distributor_qty_available']),
      nearestExpiry: map['nearest_expiry'],
    );
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    return asDouble(value);
  }
}

class ProductsResponse {
  final List<Product> products;
  final int totalCount;

  ProductsResponse({required this.products, required this.totalCount});
}
