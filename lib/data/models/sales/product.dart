import 'package:secondary_sales/core/util/parse.dart';

class Product {
  final int id;
  final String name;
  final String? code;
  final double price;
  final double? rewardPrice;
  final double? rewardDiscountRate;
  final bool hasRewardDiscount;
  final String? uom;
  final double? stock;
  final double? distributorStock;
  final String? nearestExpiry;
  final int? categoryId;
  final String? categoryName;

  Product({
    required this.id,
    required this.name,
    this.code,
    required this.price,
    this.rewardPrice,
    this.rewardDiscountRate,
    this.hasRewardDiscount = false,
    this.uom,
    this.stock,
    this.distributorStock,
    this.nearestExpiry,
    this.categoryId,
    this.categoryName,
  });

  /// The effective price after promotional loyalty rewards (if any), otherwise standard base price.
  double get effectivePrice =>
      (hasRewardDiscount && rewardPrice != null && rewardPrice! > 0) ? rewardPrice! : price;

  factory Product.fromMap(Map<String, dynamic> map) {
    final categ = map['category'] ?? map['categ'];
    final basePrice = asDouble(map['list_price'] ?? map['base_price']);
    final rewPrice = _nullableDouble(map['reward_price'] ?? map['display_price']);
    final rewRate = _nullableDouble(map['reward_discount_rate']);
    final hasReward = map['has_reward_discount'] == true;

    return Product(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      code: map['default_code'],
      price: basePrice,
      rewardPrice: rewPrice,
      rewardDiscountRate: rewRate,
      hasRewardDiscount: hasReward,
      uom: map['uom_name'] ?? map['uom']?['name'] ?? 'Unit',
      stock: _nullableDouble(map['qty_available'] ?? map['stock']),
      distributorStock: _nullableDouble(map['distributor_qty_available']),
      nearestExpiry: map['nearest_expiry'],
      categoryId: asInt(map['category_id'] ?? map['categ_id'] ?? (categ is Map ? categ['id'] : null)),
      categoryName: map['category_name']?.toString() ?? (categ is Map ? categ['name']?.toString() : null),
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
