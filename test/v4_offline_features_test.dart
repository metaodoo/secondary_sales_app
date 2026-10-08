import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    final db = await OfflineDatabaseHelper.instance.database;
    await db.delete(OfflineDatabaseHelper.tableSecondaryOrdersCache);
    await db.delete(OfflineDatabaseHelper.tableMtSessionAudits);
    await db.delete(OfflineDatabaseHelper.tableMtJourneyPlans);
    await db.delete(OfflineDatabaseHelper.tableOutbox);
  });

  group('V4 Offline Architecture Tests (MF-40, MF-52, MF-54, MF-56, MF-57)', () {
    test('1. Secondary Orders 30-Day Cache: Save, Query & Optimistic Insert (MF-40)', () async {
      final dbHelper = OfflineDatabaseHelper.instance;

      // 1. Save historical orders fetched from server
      await dbHelper.saveCachedSecondaryOrders([
        {
          'id': 1001,
          'name': 'SO-2026-001',
          'partner_id': 50,
          'partner_name': 'Meena Store Mirpur',
          'distributor_id': 12,
          'date_order': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          'amount_total': 1540.0,
          'state': 'sale',
          'lines': [
            {'product_id': 1, 'name': 'Energy Biscuit', 'quantity': 24, 'price_unit': 50.0},
          ],
        },
        {
          'id': 1002,
          'name': 'SO-2026-002',
          'partner_id': 50,
          'partner_name': 'Meena Store Mirpur',
          'distributor_id': 12,
          'date_order': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
          'amount_total': 800.0,
          'state': 'done',
          'lines': [
            {'product_id': 2, 'name': 'Butter Toast', 'quantity': 10, 'price_unit': 80.0},
          ],
        },
      ]);

      // 2. Query orders for outlet 50
      final outletOrders = await dbHelper.getCachedSecondaryOrders(outletId: 50);
      expect(outletOrders.length, equals(2));
      expect(outletOrders.first['name'], equals('SO-2026-001'));
      expect(outletOrders.first['amount_total'], equals(1540.0));

      // 3. Optimistic local insert when rep places order offline
      await dbHelper.saveOptimisticSecondaryOrder(
        clientOrderUuid: 'offline-uuid-999',
        outletId: 50,
        outletName: 'Meena Store Mirpur',
        distributorId: 12,
        amountTotal: 2500.0,
        lines: [
          {'product_id': 1, 'quantity': 50, 'price_unit': 50.0},
        ],
      );

      final updatedOrders = await dbHelper.getCachedSecondaryOrders(outletId: 50);
      expect(updatedOrders.length, equals(3));
      final pendingOrder = updatedOrders.firstWhere((o) => o['sync_status'] == 'PENDING');
      expect(pendingOrder['amount_total'], equals(2500.0));
      expect(pendingOrder['state'], equals('draft'));
    });

    test('2. Secondary Orders 30-Day Strict Retention Pruning (MF-40)', () async {
      final dbHelper = OfflineDatabaseHelper.instance;
      final db = await dbHelper.database;

      // Insert an order from 45 days ago (should be pruned)
      await db.insert(
        OfflineDatabaseHelper.tableSecondaryOrdersCache,
        {
          'server_id': 9901,
          'client_order_uuid': 'old-uuid-1',
          'name': 'SO-OLD-45-DAYS',
          'partner_id': 50,
          'partner_name': 'Meena Store',
          'distributor_id': 12,
          'date_order': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
          'amount_total': 500.0,
          'state': 'done',
          'sync_status': 'SYNCED',
          'created_at': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
        },
      );

      // Insert an order from 10 days ago (should be retained)
      await db.insert(
        OfflineDatabaseHelper.tableSecondaryOrdersCache,
        {
          'server_id': 9902,
          'client_order_uuid': 'recent-uuid-2',
          'name': 'SO-RECENT-10-DAYS',
          'partner_id': 50,
          'partner_name': 'Meena Store',
          'distributor_id': 12,
          'date_order': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
          'amount_total': 900.0,
          'state': 'done',
          'sync_status': 'SYNCED',
          'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        },
      );

      // Run pruning
      final prunedCount = await dbHelper.pruneSecondaryOrdersOlderThan30Days();
      expect(prunedCount, greaterThanOrEqualTo(1));

      // Verify only recent order remains
      final remaining = await dbHelper.getCachedSecondaryOrders(outletId: 50);
      expect(remaining.length, equals(1));
      expect(remaining.first['name'], equals('SO-RECENT-10-DAYS'));
    });

    test('3. Modern Trade Project Journey Plans (PJP) SQLite Hydration (MF-52)', () async {
      final dbHelper = OfflineDatabaseHelper.instance;

      await dbHelper.saveMtJourneyPlans([
        {
          'id': 201,
          'name': 'Shwapno Super Shop - Gulshan 1',
          'ss_code': 'MT-SHW-01',
          'owner_name': 'ACI Logistics',
          'phone': '01700000001',
          'street': 'Gulshan Avenue, Dhaka',
          'latitude': 23.7808,
          'longitude': 90.4152,
          'radius_meters': 200.0,
          'pjp_id': 88,
          'planned_date': '2026-10-08',
          'sequence': 1,
          'requires_justification': false,
        },
        {
          'id': 202,
          'name': 'Unimart - Dhanmondi',
          'ss_code': 'MT-UNI-02',
          'owner_name': 'United Group',
          'phone': '01700000002',
          'street': 'Road 27, Dhanmondi',
          'latitude': 23.7510,
          'longitude': 90.3725,
          'radius_meters': 250.0,
          'pjp_id': 88,
          'planned_date': '2026-10-08',
          'sequence': 2,
          'requires_justification': false,
        },
      ]);

      final plans = await dbHelper.getMtJourneyPlans();
      expect(plans.length, equals(2));
      expect(plans[0]['name'], equals('Shwapno Super Shop - Gulshan 1'));
      expect(plans[1]['name'], equals('Unimart - Dhanmondi'));

      // Search filter test
      final searchResult = await dbHelper.getMtJourneyPlans(searchQuery: 'Dhanmondi');
      expect(searchResult.length, equals(1));
      expect(searchResult.first['name'], equals('Unimart - Dhanmondi'));
    });

    test('4. MT Stock Audit Session Cache & 24h Purge (MF-56, MF-57)', () async {
      final dbHelper = OfflineDatabaseHelper.instance;
      final db = await dbHelper.database;

      // 1. Save an active session audit
      await dbHelper.saveMtSessionStockAudit({
        'id': 'session-audit-101',
        'outlet_id': 201,
        'outlet_name': 'Shwapno Gulshan',
        'type': 'opening_stock',
        'type_label': 'Opening Stock',
        'state': 'draft',
        'date': DateTime.now().toIso8601String(),
        'visit_id': 505,
        'notes': 'Counted shelf A and B',
        'lines': [
          {'product_id': 1, 'stock_count': 120.0},
          {'product_id': 2, 'stock_count': 45.0},
        ],
        'is_synced': 0,
      });

      // 2. Query session audits
      final sessionAudits = await dbHelper.getMtSessionStockAudits(outletId: 201);
      expect(sessionAudits.length, equals(1));
      expect(sessionAudits.first['type'], equals('opening_stock'));
      expect(sessionAudits.first['lines'].length, equals(2));
      expect(sessionAudits.first['pending_sync'], isTrue);

      // 3. Insert a 48h old synced audit to test auto-prune
      await db.insert(
        OfflineDatabaseHelper.tableMtSessionAudits,
        {
          'id': 'old-synced-audit',
          'outlet_id': 201,
          'outlet_name': 'Shwapno Gulshan',
          'type': 'opening_stock',
          'type_label': 'Opening Stock',
          'state': 'confirm',
          'date': DateTime.now().subtract(const Duration(hours: 48)).toIso8601String(),
          'visit_id': 400,
          'notes': 'Old audit',
          'total_lines': 1,
          'total_stock_count': 10.0,
          'lines_json': '[]',
          'created_at': DateTime.now().subtract(const Duration(hours: 48)).toIso8601String(),
          'is_synced': 1,
        },
      );

      final pruned = await dbHelper.pruneOldMtSessionStockAudits();
      expect(pruned, greaterThanOrEqualTo(1));

      // Verify active session audit is preserved
      final remaining = await dbHelper.getMtSessionStockAudits(outletId: 201);
      expect(remaining.length, equals(1));
      expect(remaining.first['notes'], equals('Counted shelf A and B'));
    });

    test('5. MT Outbox Enqueue & Verification for Justification and Stock Audits (MF-54, MF-56)', () async {
      final dbHelper = OfflineDatabaseHelper.instance;

      // Enqueue MT justification
      final justUuid = await dbHelper.enqueueOperation(
        entityType: 'mt_justification',
        endpoint: '/api/v1/mt/justification/create',
        payload: {
          'outlet_id': 201,
          'justification_type': 'off_schedule',
          'reason': 'Customer requested emergency restock',
          'latitude': 23.7808,
          'longitude': 90.4152,
        },
      );
      expect(justUuid, isNotEmpty);

      // Enqueue MT stock audit
      final auditUuid = await dbHelper.enqueueOperation(
        entityType: 'mt_stock_audit',
        endpoint: '/api/v1/mt/stock-audits/create',
        payload: {
          'outlet_id': 201,
          'type': 'opening_stock',
          'lines': [
            {'product_id': 1, 'stock_count': 120.0},
          ],
        },
      );
      expect(auditUuid, isNotEmpty);

      final pending = await dbHelper.getPendingOperations();
      expect(pending.length, equals(2));
      expect(pending.any((op) => op['entity_type'] == 'mt_justification'), isTrue);
      expect(pending.any((op) => op['entity_type'] == 'mt_stock_audit'), isTrue);
    });
  });
}
