import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/core/services/offline_sync_engine.dart';
import 'package:secondary_sales/data/api/api_service.dart';

/// F3: a visit checked in and out offline must check out the visit the
/// server created, not the app's temporary visit ID.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const serverVisitId = 77;
  late OfflineDatabaseHelper dbHelper;

  /// Requests the fake server received, as (path, params).
  final received = <(String, Map<String, dynamic>)>[];

  /// The API singleton keeps the client it was built with, so one fake
  /// client serves both phases and [online] switches its behaviour.
  var online = false;
  final client = MockClient((request) async {
    if (!online) throw const SocketException('Network is unreachable');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final params = Map<String, dynamic>.from(body['params'] as Map? ?? {});
    received.add((request.url.path, params));
    final data = request.url.path.endsWith('/visits/create')
        ? {'id': serverVisitId}
        : <String, dynamic>{};
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'result': {'success': true, 'data': data}}),
      200,
    );
  });

  Future<List<Map<String, Object?>>> outbox() async {
    final db = await dbHelper.database;
    return db.query(OfflineDatabaseHelper.tableOutbox, orderBy: 'id');
  }

  // Own database directory: test files run in parallel and would otherwise
  // share one outbox.
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('visit_id_patch_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    dbHelper = OfflineDatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete(OfflineDatabaseHelper.tableOutbox);
    received.clear();
    online = false;
  });

  test('an offline check-out is sent to the visit the server created', () async {
    // Offline: check in, then check out of the visit the app was handed.
    final tempVisitId = await http.runWithClient(() async {
      ApiService.instance.updateEmployeeId(208);
      final visit = await ApiService.instance.createVisit(208, 108595);
      final id = visit['id'] as int;
      await ApiService.instance.updateVisit(
        id,
        checkOutTime: DateTime.now().toUtc().toIso8601String(),
        visitReasonId: 1,
      );
      return id;
    }, () => client);

    final queued = await outbox();
    expect(queued, hasLength(2));
    expect(queued[1]['endpoint'], '/api/v1/visits/$tempVisitId/update');

    // Online again: one sync pass.
    online = true;
    await http.runWithClient(
      OfflineSyncEngine.instance.processOutboxQueueDirect,
      () => client,
    );

    final paths = received.map((r) => r.$1).toList();
    expect(paths, contains('/api/v1/visits/$serverVisitId/update'));
    expect(paths.where((p) => p.contains('/visits/$tempVisitId')), isEmpty);
    final create = received.firstWhere((r) => r.$1.endsWith('/visits/create'));
    expect(create.$2.containsKey('_temp_visit_id'), isFalse);
    expect(await outbox(), isEmpty);
  });

  test('a quarantined check-out is patched too, so Retry can succeed', () async {
    final db = await dbHelper.database;
    await db.insert(OfflineDatabaseHelper.tableOutbox, {
      'operation_uuid': 'checkout-1',
      'entity_type': 'visit_update',
      'endpoint': '/api/v1/visits/1793080263/update',
      'payload_json': jsonEncode({'visit_id': 1793080263}),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'QUARANTINED',
      'retry_count': 0,
    });

    await dbHelper.patchVisitId(1793080263, serverVisitId);

    final op = (await outbox()).single;
    expect(op['endpoint'], '/api/v1/visits/$serverVisitId/update');
    expect(jsonDecode(op['payload_json'] as String)['visit_id'], serverVisitId);
  });

  test('only the matching visit ID is replaced', () async {
    final db = await dbHelper.database;
    await db.insert(OfflineDatabaseHelper.tableOutbox, {
      'operation_uuid': 'checkout-2',
      'entity_type': 'visit_update',
      'endpoint': '/api/v1/visits/17930802631/update',
      'payload_json': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'PENDING',
      'retry_count': 0,
    });

    await dbHelper.patchVisitId(1793080263, serverVisitId);

    expect((await outbox()).single['endpoint'], '/api/v1/visits/17930802631/update');
  });
}
