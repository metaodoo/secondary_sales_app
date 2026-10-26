import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late OfflineDatabaseHelper dbHelper;

  Future<void> insertOp(String uuid, String status) async {
    final db = await dbHelper.database;
    await db.insert(OfflineDatabaseHelper.tableOutbox, {
      'operation_uuid': uuid,
      'entity_type': 'order',
      'endpoint': '/api/v1/sale-orders/create',
      'payload_json': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': status,
      'retry_count': 0,
    });
  }

  // Own database directory: test files run in parallel and would otherwise
  // share one outbox, letting another file's sync pass replay these rows.
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('logout_guard_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    dbHelper = OfflineDatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete(OfflineDatabaseHelper.tableOutbox);
  });

  group('Unsynced count', () {
    test('is zero for an empty outbox', () async {
      expect(await dbHelper.getUnsyncedCount(), 0);
    });

    test('counts pending, syncing and quarantined operations', () async {
      await insertOp('op-pending', 'PENDING');
      await insertOp('op-syncing', 'SYNCING');
      await insertOp('op-quarantined', 'QUARANTINED');
      expect(await dbHelper.getUnsyncedCount(), 3);
    });
  });

  group('AuthProvider.logout with unsynced documents', () {
    test('refuses a user-initiated logout', () async {
      await insertOp('op-pending', 'PENDING');
      final auth = AuthProvider();

      expect(await auth.logout(), isFalse);
      expect(auth.tokenRefreshFailed, isFalse);
      expect(auth.signedOutReason, isNull);
    });

    test('refuses while only quarantined operations remain', () async {
      await insertOp('op-quarantined', 'QUARANTINED');
      final auth = AuthProvider();

      expect(await auth.logout(), isFalse);
    });

    test('suppresses an involuntary logout and marks the token dead', () async {
      await insertOp('op-syncing', 'SYNCING');
      final auth = AuthProvider();

      expect(
        await auth.logout(callServer: false, reason: 'session_expired'),
        isFalse,
      );
      expect(auth.tokenRefreshFailed, isTrue);
      expect(auth.signedOutReason, isNull);
    });
  });
}
