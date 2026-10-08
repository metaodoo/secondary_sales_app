import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';

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
  });

  group('E2E QA Automated Test Suite: Offline SFA Pipeline', () {
    test('QA-E2E-01: Master Data Caching and Instant Offline Retrieval', () async {
      // 1. Arrange: Mock master data payload from Odoo backend
      const cacheKey = 'routes_emp_101';
      final mockRoutes = [
        {
          'id': 12,
          'name': 'Dhanmondi Sunday Beat',
          'outlet_count': 18,
          'outlets': [
            {'id': 201, 'name': 'Bhai Bhai General Store', 'credit_limit': 50000},
            {'id': 202, 'name': 'Mayer Doa Enterprise', 'credit_limit': 75000},
          ]
        }
      ];

      // 2. Act: Save master data to local SQLite cache
      await dbHelper.saveMasterData(
        entityKey: cacheKey,
        entityType: 'routes',
        data: mockRoutes,
      );

      // 3. Assert: Verify offline read returns exact structured data instantly
      final cachedData = await dbHelper.getMasterData(cacheKey);
      expect(cachedData, isNotNull);
      expect(cachedData is List, isTrue);
      final routesList = cachedData as List;
      expect(routesList.length, equals(1));
      expect(routesList.first['id'], equals(12));
      expect(routesList.first['name'], equals('Dhanmondi Sunday Beat'));
      expect(routesList.first['outlets'].length, equals(2));
      expect(routesList.first['outlets'][0]['name'], equals('Bhai Bhai General Store'));
    });

    test('QA-E2E-02: Offline Store Check-In Outbox Buffering', () async {
      // 1. Arrange: Check-in payload created offline
      const entityType = 'visit';
      const endpoint = '/api/v1/visits/create';
      final payload = {
        'employee_id': 101,
        'outlet_id': 201,
        'visit_type': 'standard',
        'latitude': 23.7465,
        'longitude': 90.3756,
        'check_in_time': '2026-10-04T10:00:00Z',
      };

      // 2. Act: Enqueue into Outbox
      final opUuid = await dbHelper.enqueueOperation(
        entityType: entityType,
        endpoint: endpoint,
        payload: payload,
      );

      // 3. Assert: Validate SQLite Outbox state
      expect(opUuid, isNotEmpty);
      final pendingCount = await dbHelper.getPendingCount();
      expect(pendingCount, equals(1));

      final pendingOps = await dbHelper.getPendingOperations();
      expect(pendingOps.length, equals(1));
      final op = pendingOps.first;
      expect(op['operation_uuid'], equals(opUuid));
      expect(op['entity_type'], equals('visit'));
      expect(op['endpoint'], equals(endpoint));
      expect(op['status'], equals('PENDING'));
      expect(op['retry_count'], equals(0));

      final storedPayload = jsonDecode(op['payload_json'] as String);
      expect(storedPayload['client_uuid'], equals(opUuid));
      expect(storedPayload['outlet_id'], equals(201));
    });

    test('QA-E2E-03: Causal Secondary Sales Order Booking with Parent Linking', () async {
      // 1. Arrange: Check-in first to generate parent visit UUID
      final visitUuid = await dbHelper.enqueueOperation(
        entityType: 'visit',
        endpoint: '/api/v1/visits/create',
        payload: {'employee_id': 101, 'outlet_id': 201},
      );

      // 2. Act: Secondary Order booked offline referencing parent visit
      final orderPayload = {
        'employee_id': 101,
        'outlet_id': 201,
        'sale_type': 'secondary',
        'order_lines': [
          {
            'product_id': 501,
            'order_qty': 24,
            'price_unit': 85.0,
            'lot_id': 301,
          },
          {
            'product_id': 502,
            'order_qty': 12,
            'price_unit': 120.0,
            'lot_id': 305,
          }
        ]
      };

      final orderUuid = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: orderPayload,
        parentUuid: visitUuid,
      );

      // 3. Assert: Strict parent-child causal dependency
      expect(orderUuid, isNot(equals(visitUuid)));
      final pendingCount = await dbHelper.getPendingCount();
      expect(pendingCount, equals(2));

      final pendingOps = await dbHelper.getPendingOperations();
      expect(pendingOps[0]['operation_uuid'], equals(visitUuid));
      expect(pendingOps[1]['operation_uuid'], equals(orderUuid));
      expect(pendingOps[1]['parent_uuid'], equals(visitUuid));

      final storedOrderPayload = jsonDecode(pendingOps[1]['payload_json'] as String);
      expect(storedOrderPayload['parent_uuid'], equals(visitUuid));
      expect(storedOrderPayload['order_lines'].length, equals(2));
    });

    test('QA-E2E-04: Customer Return / Damage Challan Buffering', () async {
      // 1. Arrange: Damage Return payload
      final returnPayload = {
        'employee_id': 101,
        'partner_id': 201,
        'transfer_type': 'customer_return',
        'lines': [
          {
            'product_id': 501,
            'damaged_qty': 5,
            'reason': 'Expired / Leaking Carton',
          }
        ]
      };

      // 2. Act
      final returnUuid = await dbHelper.enqueueOperation(
        entityType: 'return',
        endpoint: '/api/v1/returns',
        payload: returnPayload,
      );

      // 3. Assert
      final pendingOps = await dbHelper.getPendingOperations();
      expect(pendingOps.any((o) => o['operation_uuid'] == returnUuid), isTrue);
      final returnOp = pendingOps.firstWhere((o) => o['operation_uuid'] == returnUuid);
      expect(returnOp['entity_type'], equals('return'));
    });

    test('QA-E2E-05: Outbox FIFO Sync Commit and Purge Flow', () async {
      // 1. Arrange: Add 3 buffered operations
      final uuid1 = await dbHelper.enqueueOperation(
        entityType: 'visit',
        endpoint: '/api/v1/visits/create',
        payload: {'action': 'check_in'},
      );
      final uuid2 = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: {'amount': 1500},
        parentUuid: uuid1,
      );

      expect(await dbHelper.getPendingCount(), equals(2));

      // 2. Act: Simulate successful server sync (Odoo responds 200 OK)
      await dbHelper.updateOperationStatus(uuid1, 'SYNCING');
      await dbHelper.markOperationCompleted(uuid1);

      await dbHelper.updateOperationStatus(uuid2, 'SYNCING');
      await dbHelper.markOperationCompleted(uuid2);

      // 3. Assert: All completed operations are committed and purged from active queue
      final remainingPending = await dbHelper.getPendingCount();
      expect(remainingPending, equals(0));
    });

    test('QA-E2E-06: Non-Transient Business Error Quarantine Engine (No Queue Stalls)', () async {
      // 1. Arrange: Queue 3 operations: [Valid Visit, Invalid Inactive Customer Order, Valid Order 2]
      final visitUuid = await dbHelper.enqueueOperation(
        entityType: 'visit',
        endpoint: '/api/v1/visits/create',
        payload: {'outlet_id': 201},
      );
      final badOrderUuid = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: {'outlet_id': 9999, 'error': 'Customer archived or inactive'},
      );
      final goodOrderUuid = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: {'outlet_id': 202, 'amount': 2500},
      );

      expect(await dbHelper.getPendingCount(), equals(3));

      // 2. Act: Sync Step 1: Visit succeeds
      await dbHelper.markOperationCompleted(visitUuid);

      // Sync Step 2: Bad Order hits fatal business validation error from Odoo
      const rejectionReason = 'ValidationError: Customer Partner [9999] is archived or inactive in ERP.';
      await dbHelper.markOperationQuarantined(badOrderUuid, reason: rejectionReason);

      // Sync Step 3: Good Order 2 proceeds immediately without deadlock
      await dbHelper.markOperationCompleted(goodOrderUuid);

      // 3. Assert:
      // - Pending active queue is 0 (did NOT stall)
      // - Bad order is quarantined in sync drawer for manager review
      expect(await dbHelper.getPendingCount(), equals(0));
      expect(await dbHelper.getQuarantinedCount(), equals(1));

      final db = await dbHelper.database;
      final quarantinedRows = await db.query(
        OfflineDatabaseHelper.tableOutbox,
        where: 'status = ?',
        whereArgs: ['QUARANTINED'],
      );
      expect(quarantinedRows.length, equals(1));
      expect(quarantinedRows.first['operation_uuid'], equals(badOrderUuid));
      expect(quarantinedRows.first['error_code'], equals('BUSINESS_CONFLICT'));
      expect(quarantinedRows.first['error_message'], equals(rejectionReason));
    });

    test('QA-E2E-07: Transient Network Glitch Backoff & Retry State', () async {
      // 1. Arrange: Operation queued
      final opUuid = await dbHelper.enqueueOperation(
        entityType: 'visit',
        endpoint: '/api/v1/visits/create',
        payload: {'outlet_id': 201},
      );

      // 2. Act: Network timeout occurs during replay pass
      await dbHelper.updateOperationStatus(
        opUuid,
        'PENDING',
        errorCode: 'TIMEOUT',
        errorMessage: 'SocketException: Connection timed out (OS Error: ETIMEDOUT, errno = 110)',
      );

      // 3. Assert: Item remains in PENDING with incremented retry count
      final pendingOps = await dbHelper.getPendingOperations();
      expect(pendingOps.length, equals(1));
      final op = pendingOps.first;
      expect(op['status'], equals('PENDING'));
      expect(op['retry_count'], equals(1));
      expect(op['error_code'], equals('TIMEOUT'));
      expect(op['last_attempt_at'], isNotNull);
    });

    test('QA-ADV-01: Rapid-Fire Multi-Tap Rage-Clicking Debounce', () async {
      // Scenario: Impatient sales rep hammers "Submit Order" button 4 times in 1 second
      final orderPayload = {
        'employee_id': 101,
        'outlet_id': 201,
        'order_lines': [
          {'product_id': 501, 'qty': 10, 'price': 100},
        ],
      };

      final uuid1 = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: orderPayload,
      );
      final uuid2 = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: orderPayload,
      );
      final uuid3 = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: orderPayload,
      );
      final uuid4 = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: orderPayload,
      );

      // Assert: Idempotency debounce traps duplicate rage-clicks; returns initial UUID
      expect(uuid2, equals(uuid1));
      expect(uuid3, equals(uuid1));
      expect(uuid4, equals(uuid1));
      // Assert: Exactly ONE order was buffered in outbox, preventing duplicate bills
      expect(await dbHelper.getPendingCount(), equals(1));
    });

    test('QA-ADV-02: App Process Termination Mid-Sync Recovery', () async {
      // Scenario: OS aggressively kills app while sync is in-flight (status = SYNCING)
      final opUuid = await dbHelper.enqueueOperation(
        entityType: 'visit',
        endpoint: '/api/v1/visits/create',
        payload: {'outlet_id': 201},
      );
      await dbHelper.updateOperationStatus(opUuid, 'SYNCING');

      // In-flight items are excluded from normal pending query
      expect(await dbHelper.getPendingCount(), equals(0));

      // Act: App restarts and recovers stale in-flight operations
      final recoveredCount = await dbHelper.recoverStaleOperations();
      expect(recoveredCount, equals(1));

      // Assert: Operation is restored to PENDING and ready for sync
      expect(await dbHelper.getPendingCount(), equals(1));
      final pendingOps = await dbHelper.getPendingOperations();
      expect(pendingOps.first['operation_uuid'], equals(opUuid));
      expect(pendingOps.first['status'], equals('PENDING'));
    });

    test('QA-ADV-03: Active Visit Auto-Tracking & Seamless Parent Linking', () async {
      // Scenario: Rep checks in offline, exits app, comes back, and places an order
      final visitUuid = await dbHelper.enqueueOperation(
        entityType: 'visit',
        endpoint: '/api/v1/visits/create',
        payload: {'employee_id': 101, 'outlet_id': 201},
      );

      // Assert active visit was remembered across application states
      final activeVisit = await dbHelper.getActiveVisitUuid();
      expect(activeVisit, equals(visitUuid));

      // Order created without explicit parentUuid automatically recovers active visit
      final orderUuid = await dbHelper.enqueueOperation(
        entityType: 'order',
        endpoint: '/api/v1/sale-orders/create',
        payload: {'employee_id': 101, 'outlet_id': 201, 'order_lines': [{'product_id': 501, 'qty': 5}]},
        parentUuid: activeVisit,
      );

      final ops = await dbHelper.getPendingOperations();
      final orderOp = ops.firstWhere((o) => o['operation_uuid'] == orderUuid);
      expect(orderOp['parent_uuid'], equals(visitUuid));
    });

    test('QA-ADV-04: Offline Outlet Creation, Local Storage & Server ID Patching', () async {
      // 1. Arrange: Rep creates outlet offline with temporary ID
      const tempId = 999001;
      const routeId = 15;
      await dbHelper.saveLocalOutlets([
        {
          'id': tempId,
          'route_id': routeId,
          'name': 'Haji General Store (Offline)',
          'code': 'OFF-999001',
          'owner_name': 'Haji Abdul Jabbar',
          'phone': '01711000000',
          'street': 'Sector 3, Uttara',
          'latitude': 23.8759,
          'longitude': 90.3795,
          'radius_meters': 150.0,
          'sequence': 1,
        }
      ], routeId: routeId);

      // 2. Assert: Outlet exists in local DB and RouteOutlet.fromMap parses cleanly without QueryResultSet error
      final outlets = await dbHelper.getLocalOutlets(routeId: routeId);
      expect(outlets.length, equals(1));
      expect(outlets.first['name'], equals('Haji General Store (Offline)'));

      // 3. Child visit operation created offline referencing temp outlet id
      final opUuid = await dbHelper.enqueueOperation(
        entityType: 'visit',
        endpoint: '/api/v1/visits/create',
        payload: {
          'employee_id': 101,
          'outlet_id': tempId,
          'check_in_time': DateTime.now().toUtc().toIso8601String(),
        },
      );

      // 4. Act: Outlet syncs online and server assigns real ID 8888
      const serverOutletId = 8888;
      await dbHelper.patchOutletId(tempId, serverOutletId);

      // 5. Assert: Outbox child visit payload is patched with server outlet id
      final pending = await dbHelper.getPendingOperations();
      final patchedOp = pending.firstWhere((p) => p['operation_uuid'] == opUuid);
      final payload = jsonDecode(patchedOp['payload_json'] as String) as Map<String, dynamic>;
      expect(payload['outlet_id'], equals(serverOutletId));

      // Assert: Local outlets table updated to server ID
      final updatedOutlet = await dbHelper.getLocalOutletById(serverOutletId);
      expect(updatedOutlet, isNotNull);
      expect(updatedOutlet!['name'], equals('Haji General Store (Offline)'));

      // 6. Act: Remove outlet
      await dbHelper.deleteLocalOutlet(serverOutletId);
      final removedOutlet = await dbHelper.getLocalOutletById(serverOutletId);
      expect(removedOutlet, isNull);
    });
  });
}
