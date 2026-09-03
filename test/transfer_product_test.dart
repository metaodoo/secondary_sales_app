import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';

void main() {
  group('TransferProduct Multi-Location Stock Parsing', () {
    test('should parse fresh_qty, qc_qty, and damage_qty correctly', () {
      final jsonMap = {
        'id': 101,
        'name': 'Milk 1L Box',
        'default_code': 'M1L',
        'tracking': 'lot',
        'available_qty': 65.0,
        'fresh_qty': 50.0,
        'qc_qty': 10.0,
        'damage_qty': 5.0,
        'stock_by_location': {
          'Fresh': 50.0,
          'QC': 10.0,
          'Damage': 5.0,
        },
        'uom': {'id': 1, 'name': 'Units'},
      };

      final product = TransferProduct.fromMap(jsonMap);

      expect(product.id, equals(101));
      expect(product.name, equals('Milk 1L Box'));
      expect(product.code, equals('M1L'));
      expect(product.availableQty, equals(65.0));
      expect(product.freshQty, equals(50.0));
      expect(product.qcQty, equals(10.0));
      expect(product.damageQty, equals(5.0));
      expect(product.uomName, equals('Units'));
    });

    test('should fallback to stock_by_location if top-level location keys are missing', () {
      final jsonMap = {
        'id': 102,
        'name': 'Butter 200g',
        'tracking': 'none',
        'stock_by_location': {
          'Fresh': 20.0,
          'QC': 4.0,
          'Damage': 1.0,
        },
      };

      final product = TransferProduct.fromMap(jsonMap);

      expect(product.freshQty, equals(20.0));
      expect(product.qcQty, equals(4.0));
      expect(product.damageQty, equals(1.0));
      expect(product.availableQty, equals(25.0));
    });
  });
}
