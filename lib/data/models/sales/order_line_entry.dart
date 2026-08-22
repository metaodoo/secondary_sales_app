import 'product.dart';

class OrderLineEntry {
  OrderLineEntry({
    required this.product,
    required this.quantity,
    this.damagedQty = 0,
    this.qualityQty = 0,
    this.adjustWithBill = false,
    this.discountPercent = 0.0,
  });

  final Product product;
  int quantity;
  int damagedQty;
  int qualityQty;

  /// The product is not in the van, so this return cannot be exchanged for
  /// fresh stock. It is taken back on its own and settled against the bill.
  bool adjustWithBill;

  double discountPercent;

  bool get isSelected => quantity > 0 || damagedQty > 0 || qualityQty > 0;

  /// Whether this line has anything to adjust in the first place.
  bool get hasReturn => damagedQty > 0 || qualityQty > 0;
  int get totalQty => quantity + damagedQty + qualityQty;

  /// See `OrderLineModel.billableQty` -- kept in step with the server's
  /// `sale.order.line._ss_billable_qty`.
  int get billableQty =>
      adjustWithBill ? quantity - (damagedQty + qualityQty) : quantity;

  double get grossAmount => product.price * billableQty;
  double get discountAmount => grossAmount * (discountPercent / 100);
  double get totalAmount => grossAmount - discountAmount;
}
