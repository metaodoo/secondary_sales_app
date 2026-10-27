import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/returns/screens/create_return_screen.dart';
import 'package:secondary_sales/features/scraps/screens/create_scrap_screen.dart';

import 'support/layout_harness.dart';

/// An untracked line as saved details send it.
Map<String, dynamic> _line(int id, String name, double price, double qty) => {
  'product': {
    'id': id,
    'name': name,
    'tracking': 'none',
    'list_price': price,
    'available_qty': 10.0,
    'uom': {'id': 1, 'name': 'Pcs'},
  },
  'quantity': qty,
};

/// A lot-tracked line as saved details send it: 0.0, not null, for the SO
/// and warehouse figures nobody has entered yet.
Map<String, dynamic> _lotLine(int id, String name, double price, double qty) => {
  'product': {
    'id': id,
    'name': name,
    'tracking': 'lot',
    'list_price': price,
    'available_qty': 100.0,
    'uom': {'id': 1, 'name': 'Pcs'},
  },
  'quantity': qty,
  'so_qty': 0.0,
  'warehouse_qty': 0.0,
  'lot_lines': [
    {
      'lot': {'id': 5491, 'name': '0000084', 'available_qty': 100.0},
      'quantity': qty,
      'so_qty': 0.0,
      'warehouse_qty': 0.0,
    },
  ],
};

TransferProduct _product({double price = 10.0, String tracking = 'lot'}) =>
    TransferProduct.fromMap({
      'id': 1,
      'name': 'Plain Yogurt 50g',
      'tracking': tracking,
      'list_price': price,
    });

/// The lines saved transfer 1 is served with. The app's API client keeps the
/// first HTTP client it is given, so every test shares [_client] and only
/// changes these.
List<dynamic> _lines = [];

final _client = MockClient((request) async {
  final data = RegExp(r'/(scraps|returns)/1$').hasMatch(request.url.path)
      ? {'id': 1, 'state': 'draft', 'lines': _lines}
      : <String, dynamic>{};
  return http.Response.bytes(
    utf8.encode(jsonEncode({
      'jsonrpc': '2.0',
      'result': {'success': true, 'data': data},
    })),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

/// Shows saved transfer 1, with [lines], on a 720p phone (360 dp wide).
Future<void> _pump(
  WidgetTester tester,
  Widget Function() build,
  List<dynamic> lines,
) async {
  _lines = lines;
  await pumpAppScreen(
    tester,
    build,
    size: const Size(360, 800),
    textScale: 1.0,
    client: _client,
  );
}

/// Asserts the card's subtotal, and the footer total, are [price] times the
/// lot total the card shows ("12 Pcs").
void _expectAmountMatchesShownQty(WidgetTester tester, double price) {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .toList();
  final shown = texts
      .map(RegExp(r'^(\d+) Pcs$').firstMatch)
      .whereType<RegExpMatch>()
      .single;
  final amount = (price * double.parse(shown.group(1)!)).toStringAsFixed(2);
  expect(texts, contains('Subtotal: ৳$amount'));
  expect(texts, contains('৳$amount'));
}

Widget _scrap() => const CreateScrapScreen(scrapId: 1);
Widget _return() => const CreateReturnScreen(returnId: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    await loadMaterialIcons();
    await loadInterFont();
  });

  group('VirtualTransferLineEntry.amountFor', () {
    test('list_price from the product list becomes the line price', () {
      final line = VirtualTransferLineEntry(
        product: _product(price: 95.0, tracking: 'none'),
        quantity: 3,
      );
      expect(line.priceUnit, 95.0);
      expect(line.amountFor(), 285.0);
    });

    test('a product without a price is worth nothing', () {
      final line = VirtualTransferLineEntry(
        product: TransferProduct.fromMap({
          'id': 2,
          'name': 'Butter 200g',
          'tracking': 'none',
        }),
        quantity: 4,
      );
      expect(line.priceUnit, 0.0);
      expect(line.amountFor(), 0.0);
    });

    test('a lot-tracked line sums the quantities typed on its lots', () {
      // The phone case: 12 typed on a lot, the line itself still 0.
      final line = VirtualTransferLineEntry(
        product: _product(price: 10.09),
        quantity: 0,
        lotLines: [TransferLotInput(quantity: 12), TransferLotInput(quantity: 3)],
      );
      expect(line.amountFor(), closeTo(151.35, 1e-9));
    });

    test('an unfilled 0.0 SO or warehouse figure does not zero the amount', () {
      final line = VirtualTransferLineEntry(
        product: _product(),
        quantity: 5,
        soQty: 0.0,
        qcQty: 0.0,
        lotLines: [TransferLotInput(quantity: 5, soQty: 0.0, qcQty: 0.0)],
      );
      expect(line.amountFor(), 50.0);
    });

    test('sales operation is priced on the SO figure, falling back to the '
        'quantity where none is entered', () {
      final line = VirtualTransferLineEntry(
        product: _product(),
        quantity: 0,
        lotLines: [
          TransferLotInput(quantity: 6, soQty: 4),
          TransferLotInput(quantity: 2),
        ],
      );
      expect(line.amountFor(bySoQty: true), 60.0);
    });

    test('the warehouse is priced on the warehouse figure', () {
      final lots = VirtualTransferLineEntry(
        product: _product(),
        quantity: 0,
        lotLines: [TransferLotInput(quantity: 6, qcQty: 5)],
      );
      expect(lots.amountFor(byWarehouseQty: true), 50.0);

      final untracked = VirtualTransferLineEntry(
        product: _product(tracking: 'none'),
        quantity: 6,
        qcQty: 1,
      );
      expect(untracked.amountFor(byWarehouseQty: true), 10.0);
    });
  });

  for (final (name, build, totalLabel) in [
    ('Scrap', _scrap, 'Total Scrap Amount'),
    ('Saleable Return', _return, 'Total Return Amount'),
  ]) {
    group('$name screen price', () {
      testWidgets('each priced line shows its price and subtotal, and the '
          'footer shows the total amount', (tester) async {
        await _pump(tester, build, [
          _line(1, 'Milk 1L', 50.0, 2),
          _line(2, 'Ghee 500g', 120.0, 1),
        ]);

        expect(find.text('Price: ৳50.00'), findsOneWidget);
        expect(find.text('Subtotal: ৳100.00'), findsOneWidget);
        expect(find.text(totalLabel), findsOneWidget);
        expect(find.text('৳220.00'), findsOneWidget);

        // The second card is below the fold.
        await tester.scrollUntilVisible(
          find.text('Price: ৳120.00'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Subtotal: ৳120.00'), findsOneWidget);
        await removeScreen(tester);
      });

      testWidgets('a lot-tracked line is priced on the lot total its card '
          'shows, before and after a lot quantity is typed', (tester) async {
        // The harness signs in with every permission, so the card shows the
        // quantity of the highest role; whatever it shows, the amount must
        // be price times it, and the footer must agree.
        await _pump(tester, build, [_lotLine(1, 'Plain Yogurt 50g', 10.09, 12)]);
        _expectAmountMatchesShownQty(tester, 10.09);

        await tester.enterText(find.byType(TextField), '20');
        await tester.pump();
        _expectAmountMatchesShownQty(tester, 10.09);
        await removeScreen(tester);
      });

      testWidgets('a line without a price hides the price row', (tester) async {
        await _pump(tester, build, [_line(1, 'Milk 1L', 0.0, 2)]);

        expect(find.textContaining('Price: ৳'), findsNothing);
        expect(find.textContaining('Subtotal: ৳'), findsNothing);
        expect(find.text('৳0.00'), findsOneWidget);
        await removeScreen(tester);
      });
    });
  }
}
