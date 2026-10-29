import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:secondary_sales/features/returns/screens/create_return_screen.dart';
import 'package:secondary_sales/features/scraps/screens/create_scrap_screen.dart';

import 'support/layout_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    await loadMaterialIcons();
    await loadInterFont();
  });

  final mockClient = MockClient((request) async {
    final path = request.url.path;
    Map<String, dynamic> data = {};

    if (path.endsWith('/prepare')) {
      data = {
        'employee': {'id': 208, 'name': 'Sales Officer'},
        'distributor': {'id': 10, 'name': 'Acme Traders'},
        'distributors': [
          {'id': 10, 'name': 'Acme Traders'},
        ],
        'source_location': {'id': 101, 'name': 'Acme Traders - Fresh'},
        'destination_location': {'id': 502, 'name': 'Supply Chain Bogura (FG Stock)'},
        'warehouse': {'id': 1, 'name': 'Bogura Factory Warehouse'},
      };
    } else if (path.endsWith('/products')) {
      data = {'products': []};
    }

    return http.Response.bytes(
      utf8.encode(jsonEncode({
        'jsonrpc': '2.0',
        'result': {'success': true, 'data': data},
      })),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  group('Destination Location UI in GT Returns and Scraps', () {
    testWidgets('CreateReturnScreen displays Destination Location without dropdown arrow', (tester) async {
      await pumpAppScreen(
        tester,
        () => const CreateReturnScreen(),
        size: const Size(360, 800),
        textScale: 1.0,
        client: mockClient,
      );

      // Verify the label is Destination Location, not Warehouse
      expect(find.text('Destination Location'), findsOneWidget);
      expect(find.text('Warehouse'), findsNothing);

      // Verify it displays the destination location from prepare data
      expect(find.text('Supply Chain Bogura (FG Stock)'), findsOneWidget);

      // Verify no fake dropdown arrow icon
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

      await removeScreen(tester);
    });

    testWidgets('CreateScrapScreen displays Destination Location without dropdown arrow', (tester) async {
      await pumpAppScreen(
        tester,
        () => const CreateScrapScreen(),
        size: const Size(360, 800),
        textScale: 1.0,
        client: mockClient,
      );

      // Verify the label is Destination Location, not Warehouse
      expect(find.text('Destination Location'), findsOneWidget);
      expect(find.text('Warehouse'), findsNothing);

      // Verify it displays the destination location from prepare data
      expect(find.text('Supply Chain Bogura (FG Stock)'), findsOneWidget);

      // Verify no fake dropdown arrow icon
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

      await removeScreen(tester);
    });
  });
}
