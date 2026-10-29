import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/features/routes/screens/officer_route_selection_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    final db = await OfflineDatabaseHelper.instance.database;
    await db.delete(OfflineDatabaseHelper.tableRoutes);
  });

  group('Offline Route planned_days Persistence Tests', () {
    test('saveLocalRoutes correctly persists planned_days in SQLite and getLocalRoutes hydrates it', () async {
      final dbHelper = OfflineDatabaseHelper.instance;

      final inputRoutes = [
        {
          'id': 101,
          'name': 'Route A (Planned Wednesday)',
          'distributor_id': 501,
          'outlet_count': 12,
          'sequence': 1,
          'planned_days': ['2'],
        },
        {
          'id': 102,
          'name': 'Route B (Planned Thursday)',
          'distributor_id': 501,
          'outlet_count': 18,
          'sequence': 2,
          'planned_days': ['3', '5'],
        },
        {
          'id': 103,
          'name': 'Route C (No Plan)',
          'distributor_id': 501,
          'outlet_count': 8,
          'sequence': 3,
          'planned_days': <dynamic>[],
        },
      ];

      // 1. Save to local SQLite
      await dbHelper.saveLocalRoutes(inputRoutes);

      // 2. Fetch back from local SQLite
      final fetchedRoutes = await dbHelper.getLocalRoutes(distributorId: 501);
      expect(fetchedRoutes.length, 3);

      final routeB = fetchedRoutes.firstWhere((r) => r['id'] == 102);
      expect(routeB['planned_days'], isA<List>());
      expect(routeB['planned_days'], contains('3'));
      expect(routeB['planned_days'], contains('5'));

      final routeC = fetchedRoutes.firstWhere((r) => r['id'] == 103);
      expect(routeC['planned_days'], isEmpty);

      // 3. Verify getLocalRouteById also hydrates planned_days
      final singleRoute = await dbHelper.getLocalRouteById(102);
      expect(singleRoute, isNotNull);
      expect(singleRoute!['planned_days'], contains('3'));

      // 4. Verify sortRoutesByRecommendation works with the offline hydrated routes
      // Assuming today is Thursday ('3')
      final sorted = sortRoutesByRecommendation(fetchedRoutes, '3');
      expect(sorted.first['id'], 102); // Route B is recommended today ('3') and sorted to the top
    });

    test('handles legacy routes without planned_days gracefully', () async {
      final dbHelper = OfflineDatabaseHelper.instance;

      await dbHelper.saveLocalRoutes([
        {
          'id': 201,
          'name': 'Legacy Route',
          'distributor_id': 502,
          'outlet_count': 5,
        }
      ]);

      final fetched = await dbHelper.getLocalRouteById(201);
      expect(fetched, isNotNull);
      expect(fetched!['planned_days'], isA<List>());
      expect(fetched['planned_days'], isEmpty);
    });
  });
}
