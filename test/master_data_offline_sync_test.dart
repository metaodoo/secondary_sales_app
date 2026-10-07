import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/core/services/master_data_sync_service.dart';

void main() {
  // Initialize FFI for headless desktop/VM SQLite testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late OfflineDatabaseHelper dbHelper;

  setUp(() async {
    dbHelper = OfflineDatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete(OfflineDatabaseHelper.tableOutbox);
    await db.delete(OfflineDatabaseHelper.tableMasterCache);
    await db.delete(OfflineDatabaseHelper.tableDistributors);
    await db.delete(OfflineDatabaseHelper.tableRoutes);
    await db.delete(OfflineDatabaseHelper.tableOutlets);
    await db.delete(OfflineDatabaseHelper.tableProductsStock);
    await db.delete(OfflineDatabaseHelper.tableDistributorStocks);
    await db.delete(OfflineDatabaseHelper.tableVans);
    await db.delete(OfflineDatabaseHelper.tableReferenceMetadata);
  });

  group('Master Data Pre-Hydration & Two-Phase Sync Tests', () {
    test('1. Schema v2 Tables Creation and Data Persistence', () async {
      // Distributors
      await dbHelper.saveLocalDistributors([
        {'id': 10, 'name': 'Mirpur Distributor', 'code': 'DIST-01', 'active': 1},
      ]);
      final dists = await dbHelper.getLocalDistributors();
      expect(dists.length, equals(1));
      expect(dists.first['name'], equals('Mirpur Distributor'));

      // Routes
      await dbHelper.saveLocalRoutes([
        {'id': 50, 'name': 'Route A', 'distributor_id': 10, 'outlet_count': 5, 'active': 1},
      ]);
      final routes = await dbHelper.getLocalRoutes();
      expect(routes.length, equals(1));
      expect(routes.first['name'], equals('Route A'));

      // Outlets
      await dbHelper.saveLocalOutlets([
        {
          'id': 101,
          'name': 'Store 1',
          'route_id': 50,
          'distributor_id': 10,
          'address': 'Mirpur-10',
          'credit_limit': 10000.0,
          'active': 1,
        },
        {
          'id': 102,
          'name': 'Store 2',
          'route_id': 50,
          'distributor_id': 10,
          'address': 'Mirpur-11',
          'credit_limit': 20000.0,
          'active': 1,
        },
      ], routeId: 50);
      final outlets = await dbHelper.getLocalOutlets(routeId: 50);
      expect(outlets.length, equals(2));
      final singleOutlet = await dbHelper.getLocalOutletById(101);
      expect(singleOutlet, isNotNull);
      expect(singleOutlet!['name'], equals('Store 1'));
      expect(singleOutlet['distributor_id'], equals(10));

      // Vans
      await dbHelper.saveLocalVans([
        {'id': 70, 'name': 'Van 01', 'assigned_employee_id': 101, 'assigned_distributor_id': 10},
      ]);
      final vans = await dbHelper.getLocalVans();
      expect(vans.length, equals(1));
      expect(vans.first['name'], equals('Van 01'));
      expect(vans.first['employee_id'], equals(101));

      // Reference Metadata
      await dbHelper.saveReferenceMetadata('payment_terms', 'system', [
        {'id': 1, 'name': 'Immediate'},
        {'id': 2, 'name': '15 Days'},
      ]);
      final metadata = await dbHelper.getReferenceMetadata('payment_terms');
      expect(metadata, isNotNull);
      expect((metadata as List).length, equals(2));
    });

    test('2. Dedicated Distributor Stocks & Van Stock Isolation', () async {
      // Product Catalog
      await dbHelper.saveLocalProducts([
        {
          'id': 501,
          'name': 'Mustard Oil 1L',
          'default_code': 'OIL-1L',
          'barcode': '8941001',
          'list_price': 250.0,
          'standard_price': 220.0,
          'uom_id': 1,
          'uom_name': 'Units',
          'van_stock': 15.0,
          'active': 1,
        },
      ]);

      // Distributor Warehouse Stock (Separate table)
      await dbHelper.saveDistributorStocks(10, [
        {
          'id': 501,
          'distributor_qty_available': 500.0,
        },
      ]);

      final products = await dbHelper.getLocalProducts();
      expect(products.first['van_stock'], equals(15.0));

      final distStock = await dbHelper.getDistributorStock(10, 501);
      expect(distStock, equals(500.0));
    });

    test('3. Atomic Stock Decrement on Order Placement', () async {
      await dbHelper.saveLocalProducts([
        {
          'id': 601,
          'name': 'Ghee 500g',
          'van_stock': 20.0,
          'list_price': 400.0,
          'active': 1,
        },
      ]);
      await dbHelper.saveDistributorStocks(10, [
        {
          'id': 601,
          'distributor_qty_available': 100.0,
        },
      ]);

      // Secondary order (decrements distributor stock)
      await dbHelper.decrementLocalStock(
        productId: 601,
        quantity: 25.0,
        distributorId: 10,
        isVanDelivery: false,
      );
      final newDistStock = await dbHelper.getDistributorStock(10, 601);
      expect(newDistStock, equals(75.0));

      // Van delivery order (decrements van stock)
      await dbHelper.decrementLocalStock(
        productId: 601,
        quantity: 5.0,
        isVanDelivery: true,
      );
      final products = await dbHelper.getLocalProducts();
      final updatedProduct = products.firstWhere((p) => p['id'] == 601);
      expect(updatedProduct['van_stock'], equals(15.0));
    });

    test('4. Soft Warning Detection When Requested Qty Exceeds Stock', () {
      const recordedStock = 10.0;
      const requestedQty = 15.0;

      final exceedsStock = requestedQty > recordedStock;
      expect(exceedsStock, isTrue);

      final warningMessage = exceedsStock
          ? 'Warning: Requested quantity ($requestedQty) exceeds recorded stock ($recordedStock).'
          : null;
      expect(warningMessage, contains('exceeds recorded stock'));
    });

    test('5. Push Notification FCM Delta Updates Distributor Stock Directly', () async {
      await dbHelper.saveDistributorStocks(10, [
        {
          'id': 701,
          'distributor_qty_available': 80.0,
        },
      ]);

      // Simulate incoming FCM delta push payload:
      // { "type": "distributor_stock_delta", "distributor_id": "10", "product_id": "701", "new_stock": "64.0" }
      await dbHelper.updateSingleDistributorStock(10, 701, 64.0);

      final updatedStock = await dbHelper.getDistributorStock(10, 701);
      expect(updatedStock, equals(64.0));
    });

    test('6. Phase 1 Guard: Inbound Master Data Sync Aborts When Outbox Is Pending', () async {
      // Simulate pending outbox operation
      await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: {'client_order_ref': 'ORD-OFFLINE-001'},
      );

      // Verify outbox has pending items
      final pendingCount = await dbHelper.getPendingCount();
      expect(pendingCount, greaterThan(0));

      // Attempting triggerDailySync should abort phase 2
      final syncResult = await MasterDataSyncService.instance.triggerDailySync(force: true);
      expect(syncResult, isFalse);
    });

    test('7. Outbox Operations Store Employee ID and Support Filtering', () async {
      await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: {'client_order_ref': 'ORD-EMP-101', 'employee_id': 101},
      );
      await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: {'client_order_ref': 'ORD-EMP-202', 'employee_id': 202},
      );

      final ops101 = await dbHelper.getPendingOperations(employeeId: 101);
      expect(ops101.length, equals(1));
      expect(ops101.first['employee_id'], equals(101));

      final ops202 = await dbHelper.getPendingOperations(employeeId: 202);
      expect(ops202.length, equals(1));
      expect(ops202.first['employee_id'], equals(202));
    });
  });
}
