import 'product.dart';

class OrderLineEntry {
  OrderLineEntry({
    required this.product,
    required this.quantity,
    this.discountPercent = 0.0,
  });

  final Product product;
  int quantity;
  double discountPercent;

  double get grossAmount => product.price * quantity;
  double get discountAmount => grossAmount * (discountPercent / 100);
  double get totalAmount => grossAmount - discountAmount;
}
