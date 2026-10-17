import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';

void main() {
  group('Secondary Sales Customer Order Qty Flow', () {
    final queenMarry = Product(
      id: 1,
      name: 'Queen Marry Biscuit',
      price: 5.0,
      stock: 50,
      distributorStock: 100,
    );

    final lexus = Product(
      id: 2,
      name: 'Lexus Biscuit',
      price: 5.0,
      stock: 50,
      distributorStock: 100,
    );

    test('OrderLineEntry calculates payableQty and totalAmount matching user table', () {
      // Line 1: Queen Marry Biscuit: Customer Order Qty = 24, Damaged = 10, Quality = 0
      final line1 = OrderLineEntry(
        product: queenMarry,
        customerOrderQty: 24,
        damagedQty: 10,
        qualityQty: 0,
      );

      expect(line1.customerOrderQty, 24);
      expect(line1.quantity, 24);
      expect(line1.payableQty, 14);
      expect(line1.billableQty, 14);
      expect(line1.grossAmount, 70.0);
      expect(line1.totalAmount, 70.0);

      // Line 2: Lexus Biscuit: Customer Order Qty = 0, Damaged = 5, Quality = 2
      final line2 = OrderLineEntry(
        product: lexus,
        customerOrderQty: 0,
        damagedQty: 5,
        qualityQty: 2,
      );

      expect(line2.customerOrderQty, 0);
      expect(line2.quantity, 0);
      expect(line2.payableQty, -7);
      expect(line2.billableQty, -7);
      expect(line2.grossAmount, -35.0);
      expect(line2.totalAmount, -35.0);

      // Total of both lines
      final total = line1.totalAmount + line2.totalAmount;
      expect(total, 35.0);
    });

    test('OrderLineModel calculates payableQty and lineTotal correctly', () {
      final model1 = OrderLineModel(
        productId: queenMarry.id,
        productName: queenMarry.name,
        unitPrice: queenMarry.price,
        customerOrderQty: 24,
        damagedExpiredQty: 10,
        damageQualityQty: 0,
      );

      expect(model1.customerOrderQty, 24);
      expect(model1.payableQty, 14);
      expect(model1.lineTotal, 70.0);

      final model2 = OrderLineModel(
        productId: lexus.id,
        productName: lexus.name,
        unitPrice: lexus.price,
        customerOrderQty: 0,
        damagedExpiredQty: 5,
        damageQualityQty: 2,
      );

      expect(model2.customerOrderQty, 0);
      expect(model2.payableQty, -7);
      expect(model2.lineTotal, -35.0);

      final total = model1.lineTotal + model2.lineTotal;
      expect(total, 35.0);
    });
  });
}
