import 'product.dart';

class OrderLineEntry {
  OrderLineEntry({
    required this.product,
    required this.quantity,
    this.damagedQty = 0,
    this.qualityQty = 0,
    this.discountPercent = 0.0,
  });

  final Product product;
  int quantity;
  int damagedQty;
  int qualityQty;
  double discountPercent;

  bool get isSelected => quantity > 0 || damagedQty > 0 || qualityQty > 0;
  int get totalQty => quantity + damagedQty + qualityQty;

  double get grossAmount => product.price * quantity;
  double get discountAmount => grossAmount * (discountPercent / 100);
  double get totalAmount => grossAmount - discountAmount;
}
