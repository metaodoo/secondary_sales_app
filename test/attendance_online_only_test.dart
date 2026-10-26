import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/data/api/api_service.dart';

/// Business rule: attendance requires a live connection and is never queued.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late OfflineDatabaseHelper dbHelper;

  final offlineClient = MockClient(
    (request) async => throw const SocketException('Network is unreachable'),
  );

  Future<Map<String, dynamic>> punch(String action) =>
      http.runWithClient(() async {
        return ApiService.instance.submitAttendanceAction(
          employeeId: 208,
          action: action,
          latitude: 23.839,
          longitude: 90.367,
        );
      }, () => offlineClient);

  // Own database directory: test files run in parallel and would otherwise
  // share one outbox.
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('attendance_online_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    dbHelper = OfflineDatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete(OfflineDatabaseHelper.tableOutbox);
  });

  for (final action in ['check_in', 'check_out']) {
    test('$action fails without a connection instead of being queued', () async {
      await expectLater(punch(action), throwsException);
      expect(await dbHelper.getUnsyncedCount(), 0);
    });
  }
}
