import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/features/routes/screens/create_outlet_screen.dart';
import 'package:secondary_sales/features/routes/screens/customer_action_bottom_sheet.dart';
import 'package:secondary_sales/features/routes/screens/officer_customer_selection_screen.dart';
import 'package:secondary_sales/features/routes/screens/officer_route_selection_screen.dart';
import 'package:secondary_sales/features/routes/screens/visit_reason_dialog.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';
import 'package:secondary_sales/features/sales/screens/secondary_orders_list_screen.dart';

import 'support/layout_harness.dart';

/// The GT secondary field flow (route -> outlet -> order) with full lists of
/// long names, on the phones field staff use. Fixtures in
/// test/fixtures/layout are staging responses with every name, address and
/// phone replaced by long synthetic text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Map<String, dynamic> fixture(String name) => jsonDecode(
        File('test/fixtures/layout/$name.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  final products = fixture('products');
  const longOutlet = 'Test Outlet General & Variety Store and Mobile Recharge Point 1';

  /// Answers by path, like the API; anything else gets an empty success.
  Map<String, dynamic> respond(String path) {
    if (path.endsWith('/products')) return products;
    if (path.endsWith('/sale-orders')) return fixture('sale_orders');
    if (RegExp(r'/ss/routes/\d+$').hasMatch(path)) return fixture('route_detail');
    if (path.endsWith('/ss/routes')) return fixture('routes');
    if (path.endsWith('/visits/today')) return fixture('visits_today');
    if (RegExp(r'/contacts/\d+/visits$').hasMatch(path)) return fixture('outlet_visits');
    if (path.contains('/visit-reasons')) {
      return {
        'success': true,
        'data': [
          for (var i = 1; i <= 6; i++)
            {
              'id': i,
              'name': 'Shop closed for a family program, owner will be back next week $i',
              'is_sale': i == 1,
            },
        ],
      };
    }
    return {'success': true, 'data': []};
  }

  final client = MockClient((request) async => http.Response.bytes(
        utf8.encode(jsonEncode({'jsonrpc': '2.0', 'result': respond(request.url.path)})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));

  List<OrderLineEntry> orderLines() => [
        for (final p in (products['data'] as List).take(4))
          OrderLineEntry(
            product: Product.fromMap(p as Map<String, dynamic>),
            customerOrderQty: 12345,
            damagedQty: 999,
            qualityQty: 999,
          ),
      ];

  final screens = <(String, Widget Function())>[
    ('SecondaryOrdersListScreen', () => const SecondaryOrdersListScreen()),
    ('OfficerRouteSelectionScreen', () => const OfficerRouteSelectionScreen()),
    (
      'OfficerCustomerSelectionScreen',
      () => const OfficerCustomerSelectionScreen(
            routeId: 2804,
            routeName: 'Test Route from Main Bazar to Rail Gate Road via College 1',
          ),
    ),
    (
      'CustomerActionBottomSheet',
      () => const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CustomerActionBottomSheet(
                customerName: longOutlet,
                outletId: 103802,
                customerCode: 'NART9001',
                phone: '01700000000',
              ),
            ),
          ),
    ),
    (
      'ProductSelectionScreen',
      () => const ProductSelectionScreen(
            saleType: 'secondary',
            partnerId: 103802,
            customerName: longOutlet,
            customerCode: 'NART9001',
          ),
    ),
    (
      'OrderCreationScreen',
      () => OrderCreationScreen(
            outletId: 103802,
            customerName: longOutlet,
            outletCode: 'NART9001',
            initialLines: orderLines(),
          ),
    ),
    (
      'CreateOutletScreen',
      () => const CreateOutletScreen(
            routeId: 2804,
            routeName: 'Test Route from Main Bazar to Rail Gate Road via College 1',
            distributorName: 'Test Distributor Varieties Store and Distribution House 1',
          ),
    ),
    (
      'VisitReasonDialog',
      () => const Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: VisitReasonDialog()),
          ),
    ),
  ];

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('field_flow_layout_');
    await databaseFactory.setDatabasesPath(dir.path);
    await loadInterFont();
  });

  final a11yBaseline = AccessibilityBaseline('field_flow');
  tearDownAll(a11yBaseline.save);

  for (final (name, build) in screens) {
    // One size is enough: these checks do not depend on the screen size.
    testWidgets('$name meets accessibility checks', (tester) async {
      final report = await checkScreen(
        tester,
        build,
        size: const Size(360, 800),
        textScale: 1.0,
        client: client,
        accessibility: true,
      );
      a11yBaseline.check(name, report);
    });
  }

  for (final (name, build) in screens) {
    for (final (label, size, textScale) in layoutSizes) {
      testWidgets('$name fits on $label', (tester) async {
        final report = await checkScreen(
          tester,
          build,
          size: size,
          textScale: textScale,
          client: client,
        );
        expect(report.overflows, isEmpty, reason: report.overflows.join('; '));
      });
    }
  }
}
