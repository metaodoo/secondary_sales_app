import 'product.dart';

class OrderLineEntry {
  OrderLineEntry({
    required this.product,
    int? customerOrderQty,
    int? quantity,
    this.damagedQty = 0,
    this.qualityQty = 0,
    this.adjustWithBill = false,
    this.discountPercent = 0.0,
  }) : customerOrderQty = customerOrderQty ?? quantity ?? 0;

  final Product product;
  int customerOrderQty;

  /// Backwards compatibility alias for customerOrderQty
  int get quantity => customerOrderQty;
  set quantity(int val) => customerOrderQty = val;

  int damagedQty;
  int qualityQty;

  // --- OLD FLOW (Deprecated): Flag for settling return against bill ---
  // bool adjustWithBill;
  bool adjustWithBill;
  // -------------------------------------------------------------------

  double discountPercent;

  bool get isSelected => customerOrderQty > 0 || damagedQty > 0 || qualityQty > 0;

  /// Whether this line has anything to adjust in the first place.
  bool get hasReturn => damagedQty > 0 || qualityQty > 0;
  int get totalQty => customerOrderQty + damagedQty + qualityQty;

  /// Payable quantity = customerOrderQty - (damagedQty + qualityQty)
  int get payableQty => customerOrderQty - (damagedQty + qualityQty);

  // --- OLD FLOW (Deprecated): billableQty based on adjustWithBill ---
  // int get billableQty =>
  //     adjustWithBill ? quantity - (damagedQty + qualityQty) : quantity;
  // -----------------------------------------------------------------
  int get billableQty => payableQty;

  double get grossAmount => product.price * payableQty;
  double get discountAmount => grossAmount * (discountPercent / 100);
  double get totalAmount => grossAmount - discountAmount;

  /// Effective amounts taking into account promotional loyalty reward prices
  double get effectiveGrossAmount => product.effectivePrice * payableQty;
  double get effectiveDiscountAmount => effectiveGrossAmount * (discountPercent / 100);
  double get effectiveTotalAmount => effectiveGrossAmount - effectiveDiscountAmount;
}
