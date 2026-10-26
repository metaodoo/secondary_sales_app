import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';

/// F6: the rage-click debounce must not swallow real repeat operations.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const orderEndpoint = '/api/v1/sale-orders/create';
  const attendanceEndpoint = '/api/v1/hr/attendance/action';
  const visitEndpoint = '/api/v1/ss/visits/create';
  late OfflineDatabaseHelper dbHelper;

  final order = {
    'employee_id': 101,
    'outlet_id': 201,
    'order_lines': [
      {'product_id': 501, 'qty': 10, 'price': 100},
    ],
  };

  Future<String> enqueue(
    String entityType,
    String endpoint,
    Map<String, dynamic> payload, {
    String? clientUuid,
  }) =>
      dbHelper.enqueueOperation(
        entityType: entityType,
        endpoint: endpoint,
        payload: payload,
        clientUuid: clientUuid,
      );

  /// Moves an operation's creation time [age] into the past.
  Future<void> backdate(String uuid, Duration age) async {
    final db = await dbHelper.database;
    await db.update(
      OfflineDatabaseHelper.tableOutbox,
      {'created_at': DateTime.now().toUtc().subtract(age).toIso8601String()},
      where: 'operation_uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<List<Map<String, Object?>>> outbox() async {
    final db = await dbHelper.database;
    return db.query(OfflineDatabaseHelper.tableOutbox, orderBy: 'id');
  }

  // Own database directory: test files run in parallel and would otherwise
  // share one outbox.
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('outbox_dedupe_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    dbHelper = OfflineDatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete(OfflineDatabaseHelper.tableOutbox);
  });

  test('collapses identical taps within the window into one operation', () async {
    final first = await enqueue('order', orderEndpoint, order);
    final second = await enqueue('order', orderEndpoint, order);

    expect(second, first);
    expect(await outbox(), hasLength(1));
  });

  test('keeps an identical order placed after the window', () async {
    final first = await enqueue('order', orderEndpoint, order);
    await backdate(first, const Duration(seconds: 10));
    final second = await enqueue('order', orderEndpoint, order);

    expect(second, isNot(first));
    expect(await outbox(), hasLength(2));
  });

  test('keeps the second check-in of a split shift', () async {
    final actions = ['check_in', 'check_out', 'check_in'];
    final uuids = <String>[];
    for (final action in actions) {
      uuids.add(await enqueue(
        'attendance',
        attendanceEndpoint,
        {'employee_id': 101, 'action': action},
      ));
    }

    expect(uuids.toSet(), hasLength(3));
    final queued = await outbox();
    expect(
      queued.map((op) => jsonDecode(op['payload_json'] as String)['action']),
      actions,
    );
  });

  test('keeps a second visit to the same outlet', () async {
    final visit = {'employee_id': 101, 'outlet_id': 201};
    final first = await enqueue('visit', visitEndpoint, visit);
    await backdate(first, const Duration(minutes: 2));
    final second = await enqueue('visit', visitEndpoint, visit);

    expect(second, isNot(first));
    expect(await outbox(), hasLength(2));
  });

  test('reuses an already queued client UUID without replacing it', () async {
    await enqueue('order', orderEndpoint, order, clientUuid: 'order-1');
    final db = await dbHelper.database;
    await db.update(
      OfflineDatabaseHelper.tableOutbox,
      {'status': 'SYNCING'},
      where: 'operation_uuid = ?',
      whereArgs: ['order-1'],
    );

    final again = await enqueue(
      'order',
      orderEndpoint,
      {...order, 'outlet_id': 999},
      clientUuid: 'order-1',
    );

    expect(again, 'order-1');
    final queued = await outbox();
    expect(queued, hasLength(1));
    expect(queued.single['status'], 'SYNCING');
    expect(jsonDecode(queued.single['payload_json'] as String)['outlet_id'], 201);
  });
}
