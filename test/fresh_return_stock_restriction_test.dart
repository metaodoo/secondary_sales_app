import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/core/widgets/stock_excess_dialog.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';

void main() {
  group('Fresh Return Stock Restriction Logic', () {
    test('TransferProduct separates freshQty from 3-location availableQty', () {
      final jsonMap = {
        'id': 101,
        'name': 'Fresh Milk 1L',
        'default_code': 'FM1',
        'tracking': 'none',
        'available_qty': 65.0,
        'fresh_qty': 50.0,
        'qc_qty': 10.0,
        'damage_qty': 5.0,
        'uom': {'id': 1, 'name': 'Pcs'},
      };

      final product = TransferProduct.fromMap(jsonMap);

      expect(product.freshQty, equals(50.0));
      expect(product.qcQty, equals(10.0));
      expect(product.damageQty, equals(5.0));
      expect(product.availableQty, equals(65.0));
    });

    test('Fresh returns must cap using freshQty, while scrap returns use availableQty', () {
      final product = TransferProduct(
        id: 101,
        name: 'Fresh Milk 1L',
        tracking: 'none',
        availableQty: 65.0,
        freshQty: 50.0,
        qcQty: 10.0,
        damageQty: 5.0,
      );

      // Simulating distributor stock mapping for Fresh Return vs Scrap Return
      double getCapForEndpoint(String endpoint, TransferProduct p) {
        final ep = endpoint.toLowerCase();
        final isFresh = !ep.contains('qc_returns') &&
            !ep.contains('scraps') &&
            !ep.contains('damaged');
        return isFresh ? p.freshQty : p.availableQty;
      }

      final freshCap = getCapForEndpoint('/api/v1/returns', product);
      final qcCap = getCapForEndpoint('/api/v1/qc_returns', product);
      final scrapCap = getCapForEndpoint('/api/v1/scraps', product);

      expect(freshCap, equals(50.0), reason: 'Fresh returns must strictly use Fresh stock (50)');
      expect(qcCap, equals(65.0), reason: 'QC returns use 3-location combined stock (65)');
      expect(scrapCap, equals(65.0), reason: 'Scrap returns use 3-location combined stock (65)');
    });

    test('StockExcessItem correctly computes excess quantity', () {
      final item = StockExcessItem(
        productName: 'Fresh Milk 1L',
        enteredQty: 55.0,
        availableQty: 50.0,
        uomName: 'Pcs',
      );

      expect(item.excessQty, equals(5.0));
      expect(item.productName, equals('Fresh Milk 1L'));
      expect(item.enteredQty, equals(55.0));
      expect(item.availableQty, equals(50.0));
      expect(item.uomName, equals('Pcs'));
    });

    test('Dynamic increase on Leg 2 (PSRT) allows increasing up to total fresh capacity', () {
      // Scenario:
      // Initial fresh on hand = 50.
      // Leg 1 SO declared so_qty = 30.
      // Reopened on Leg 2: remaining fresh = 20, recorded on load = 30.
      // Total Fresh Capacity = 20 + 30 = 50.
      final remainingFreshStock = 20.0;
      final recordedOnLoad = 30.0;
      final totalFreshCapacity = remainingFreshStock + recordedOnLoad;

      expect(totalFreshCapacity, equals(50.0));

      bool validateEnteredQty(double entered) {
        return entered <= totalFreshCapacity + 0.0001;
      }

      // Warehouse / QC physically counts 40 units (more than SO's 30)
      expect(validateEnteredQty(40.0), isTrue,
          reason: 'QC count of 40 is within distributor total fresh capacity (50)');

      // Warehouse / QC physically counts 50 units (exactly at capacity)
      expect(validateEnteredQty(50.0), isTrue,
          reason: 'QC count of 50 is exactly at distributor total fresh capacity (50)');

      // User tries to enter 55 units (exceeds distributor fresh capacity)
      expect(validateEnteredQty(55.0), isFalse,
          reason: 'QC count of 55 exceeds distributor total fresh capacity (50)');
    });

    test('Role-specific entered quantity evaluation on Fresh Return', () {
      final product = TransferProduct(
        id: 101,
        name: 'Fresh Milk 1L',
        tracking: 'none',
        availableQty: 50.0,
        freshQty: 50.0,
      );

      final line = VirtualTransferLineEntry(
        product: product,
        quantity: 50.0,
        soQty: 30.0,
        qcQty: 35.0,
        qcSaleableQty: 40.0,
      );

      // Simulating _activeEnteredQtyFor
      double getActiveQty({
        required bool isFreshReturn,
        required bool isQcSplit,
        required bool canEditWarehouseQty,
        required bool canEditSoQty,
      }) {
        if (isFreshReturn) {
          if (isQcSplit) {
            return line.qcSaleableQty ?? 0.0;
          }
          if (canEditWarehouseQty) {
            return line.qcQty ?? 0.0;
          }
        }
        return line.soQty ?? 0.0;
      }

      // 1. Sales Officer (Leg 1)
      final soQty = getActiveQty(
        isFreshReturn: true,
        isQcSplit: false,
        canEditWarehouseQty: false,
        canEditSoQty: true,
      );
      expect(soQty, equals(30.0));

      // 2. Warehouse Coordinator (Leg 2)
      final warehouseQty = getActiveQty(
        isFreshReturn: true,
        isQcSplit: false,
        canEditWarehouseQty: true,
        canEditSoQty: false,
      );
      expect(warehouseQty, equals(35.0));

      // 3. Sales Operation / QC (Leg 2)
      final qcSaleableQty = getActiveQty(
        isFreshReturn: true,
        isQcSplit: true,
        canEditWarehouseQty: false,
        canEditSoQty: false,
      );
      expect(qcSaleableQty, equals(40.0));
    });

    test('Editing/Updating Leg 1 cannot exceed on-hand stock (prevents double-counting)', () {
      // User scenario:
      // Distributor has 20 available.
      // User creates return with 20 and saves.
      // Reopening Leg 1 to edit:
      final distributorStock = 20.0;
      final recordedOnLoad = 20.0;

      double computeCap({required bool isTransitLeg}) {
        final recorded = isTransitLeg ? recordedOnLoad : 0.0;
        return distributorStock + recorded;
      }

      // On Leg 1 (PSR), stock has NOT been debited from distributor location yet.
      final leg1Cap = computeCap(isTransitLeg: false);
      expect(leg1Cap, equals(20.0), reason: 'Leg 1 cap must strictly be 20.0, NOT 40.0');

      // User keeping 20 is allowed
      expect(20.0 <= leg1Cap + 0.0001, isTrue);

      // User updating to 25 must be BLOCKED
      expect(25.0 <= leg1Cap + 0.0001, isFalse,
          reason: 'Updating to 25 when distributor only has 20 must be blocked');

      // On Leg 2 (PSRT), goods ARE in transit and debited from distributor, so transit cap applies
      final leg2Cap = computeCap(isTransitLeg: true);
      expect(leg2Cap, equals(40.0));
    });

    test('Leg 2 (PSRT) cap uses Leg 1 origin so_qty (15) + fresh stock (9) = 24 total capacity', () {
      // Scenario from PSRT00087:
      // Product 5345:
      // - Leg 1 (PSR00071) so_qty was 15.0
      // - Warehouse count was saved as 20.0
      // - Distributor remaining fresh stock is 9.0
      final testProduct = TransferProduct(
        id: 5345,
        name: '[30012] Shokti+ Plain Yogurt 50g (V1)',
        tracking: 'lot',
        availableQty: -1.0,
        freshQty: 9.0,
      );

      final line = VirtualTransferLineEntry(
        product: testProduct,
        quantity: 0.0,
        soQty: 15.0,
        qcQty: 20.0,
        qcSaleableQty: 0.0,
      );

      // On Leg 2, recordedOnLoad is based on Leg 1 declaration soQty (15.0)
      final recordedOnLoad = (line.soQty != null && line.soQty! > 0)
          ? line.soQty!
          : line.quantity;
      expect(recordedOnLoad, equals(15.0), reason: 'Leg 2 recorded must reflect Leg 1 so_qty');

      final freshStock = 9.0;
      final leg2Cap = freshStock + recordedOnLoad;
      expect(leg2Cap, equals(24.0), reason: 'Total fresh capacity = 9 fresh + 15 so_qty = 24');

      // User entering 20 on warehouse_qty: allowed (20 <= 24)
      expect(20.0 <= leg2Cap + 0.0001, isTrue);

      // User entering 24: allowed (24 <= 24)
      expect(24.0 <= leg2Cap + 0.0001, isTrue);

      // User entering 25: BLOCKED (25 > 24)
      expect(25.0 <= leg2Cap + 0.0001, isFalse);

      final excessItem = StockExcessItem(
        productName: line.product.name,
        enteredQty: 25.0,
        availableQty: leg2Cap,
        uomName: 'Pcs',
      );
      expect(excessItem.availableQty, equals(24.0));
      expect(excessItem.excessQty, equals(1.0));
    });

    test('Seeding distributor stock preserves freshQty even if /products drops product', () {
      final stockMap = <int, double>{};
      final testLine = VirtualTransferLineEntry(
        product: TransferProduct(
          id: 5345,
          name: 'Yogurt',
          tracking: 'lot',
          availableQty: -1.0, // negative 3-location sum due to damage
          freshQty: 9.0, // positive fresh stock
        ),
        quantity: 0.0,
        soQty: 15.0,
      );

      // Seed from existing lines
      stockMap.putIfAbsent(testLine.product.id, () => testLine.product.freshQty);
      expect(stockMap[5345], equals(9.0));

      // If /products returned an empty list (omitted product), stockMap retains 9.0
      final fetchedProducts = <Map<String, dynamic>>[];
      for (final p in fetchedProducts) {
        final prod = TransferProduct.fromMap(p);
        stockMap[prod.id] = prod.freshQty;
      }

      expect(stockMap[5345], equals(9.0), reason: 'Seeded freshQty must not be wiped out');
    });
  });
}
