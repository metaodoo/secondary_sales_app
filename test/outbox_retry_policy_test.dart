import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/core/services/offline_sync_engine.dart';
import 'package:secondary_sales/data/api/api_service.dart';

/// F4: retry counting and quarantine policy of the outbox replay.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const orderEndpoint = '/api/v1/sale-orders/create';
  late OfflineDatabaseHelper dbHelper;

  /// What the fake server does with an order create; other calls succeed.
  late Future<http.Response> Function() onOrderCreate;

  final mockClient = MockClient((request) async {
    if (request.url.path.endsWith(orderEndpoint)) return onOrderCreate();
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'result': {'success': true, 'data': []}}),
      200,
    );
  });

  http.Response rpcResult(Map<String, dynamic> result) =>
      http.Response(jsonEncode({'jsonrpc': '2.0', 'result': result}), 200);

  Future<void> insertOp(String uuid) async {
    final db = await dbHelper.database;
    await db.insert(OfflineDatabaseHelper.tableOutbox, {
      'operation_uuid': uuid,
      'entity_type': 'order',
      'endpoint': orderEndpoint,
      'payload_json': jsonEncode({'client_order_uuid': uuid}),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'PENDING',
      'retry_count': 0,
    });
  }

  Future<Map<String, Object?>> readOp(String uuid) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      OfflineDatabaseHelper.tableOutbox,
      where: 'operation_uuid = ?',
      whereArgs: [uuid],
    );
    return rows.single;
  }

  /// Runs [passes] sync passes with the mock HTTP client in place.
  Future<void> syncPasses(int passes) => http.runWithClient(() async {
        // Build the singleton inside the zone so it holds the mock client.
        ApiService.instance;
        for (var i = 0; i < passes; i++) {
          await OfflineSyncEngine.instance.processOutboxQueueDirect();
        }
      }, () => mockClient);

  // Own database directory: test files run in parallel and would otherwise
  // share one outbox, letting another file's sync pass replay these rows.
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('outbox_retry_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    dbHelper = OfflineDatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete(OfflineDatabaseHelper.tableOutbox);
  });

  test('counts one retry per failed attempt', () async {
    await insertOp('op-1');
    onOrderCreate = () async => throw const SocketException('No route to host');

    await syncPasses(1);

    final op = await readOp('op-1');
    expect(op['status'], 'PENDING');
    expect(op['retry_count'], 1);
  });

  test('never quarantines on repeated connection failures', () async {
    await insertOp('op-1');
    onOrderCreate =
        () async => throw http.ClientException('Connection reset by peer');

    await syncPasses(OfflineSyncEngine.kMaxOutboxRetries + 3);

    final op = await readOp('op-1');
    expect(op['status'], 'PENDING');
    expect(op['retry_count'], OfflineSyncEngine.kMaxOutboxRetries + 3);
  });

  test('never quarantines while the gateway returns 503', () async {
    await insertOp('op-1');
    onOrderCreate = () async => http.Response('Service Unavailable', 503);

    await syncPasses(OfflineSyncEngine.kMaxOutboxRetries + 1);

    expect((await readOp('op-1'))['status'], 'PENDING');
  });

  test('a dead session pauses the queue without quarantining anything', () async {
    await insertOp('op-1');
    await insertOp('op-2');
    onOrderCreate = () async => http.Response(
          jsonEncode({'error': 'unauthorized', 'reason': 'session_expired'}),
          401,
        );

    await syncPasses(1);

    final first = await readOp('op-1');
    final second = await readOp('op-2');
    expect(first['status'], 'PENDING');
    expect(second['status'], 'PENDING');
    expect(second['retry_count'], 0);
  });

  test('quarantines a recurring server rejection after the retry limit', () async {
    await insertOp('op-1');
    onOrderCreate = () async => rpcResult({
          'success': false,
          'error': 'validation_error',
          'message': 'Something went wrong on the server.',
        });

    await syncPasses(OfflineSyncEngine.kMaxOutboxRetries - 1);
    var op = await readOp('op-1');
    expect(op['status'], 'PENDING');
    expect(op['retry_count'], OfflineSyncEngine.kMaxOutboxRetries - 1);

    await syncPasses(1);
    op = await readOp('op-1');
    expect(op['status'], 'QUARANTINED');
    expect(op['error_code'], 'MAX_RETRIES');
  });

  test('quarantines a permanent business conflict at once', () async {
    await insertOp('op-1');
    onOrderCreate = () async => rpcResult({
          'success': false,
          'error': 'validation_error',
          'message': 'The customer is archived.',
        });

    await syncPasses(1);

    final op = await readOp('op-1');
    expect(op['status'], 'QUARANTINED');
    expect(op['error_code'], 'BUSINESS_CONFLICT');
  });
}
