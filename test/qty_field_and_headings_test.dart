import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/sales/screens/home_tab.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';

import 'support/layout_harness.dart';

/// Products from the layout fixtures; anything else gets an empty success,
/// so the attendance lists are empty. The app's API client keeps the first
/// HTTP client it is given, so every test shares this one.
final _products = jsonDecode(
  File('test/fixtures/layout/products.json').readAsStringSync(),
) as Map<String, dynamic>;

final _client = MockClient((request) async {
  final result = request.url.path.endsWith('/products')
      ? _products
      : {'success': true, 'data': []};
  return http.Response.bytes(
    utf8.encode(jsonEncode({'jsonrpc': '2.0', 'result': result})),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

/// Shows [build] on a 720p phone (360 dp wide).
Future<void> _pump(WidgetTester tester, Widget Function() build) =>
    pumpAppScreen(
      tester,
      build,
      size: const Size(360, 800),
      textScale: 1.0,
      client: _client,
    );

final _qtyField = find.byWidgetPredicate(
  (w) => w is TextField && w.keyboardType == TextInputType.number,
);

/// Types [text] into [field] the way the keyboard does: it replaces
/// whatever is selected.
Future<void> _type(WidgetTester tester, Finder field, String text) async {
  final value = tester
      .state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)))
      .textEditingValue;
  final newText = value.selection.textBefore(value.text) + text + value.selection.textAfter(value.text);
  tester.testTextInput.updateEditingValue(TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: value.selection.textBefore(value.text).length + text.length,
    ),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    await loadMaterialIcons();
    await loadInterFont();
  });

  group('Order qty field', () {
    testWidgets('typing after tapping replaces the number', (tester) async {
      await _pump(
        tester,
        () => const ProductSelectionScreen(partnerId: 59646, customerName: 'Test Distributor'),
      );
      final field = _qtyField.first;
      final plus = find.descendant(
        of: find.ancestor(of: field, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '2');

      await tester.tap(field);
      await tester.pump();
      final controller = tester.widget<TextField>(field).controller!;
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 1));

      await _type(tester, field, '12');
      expect(controller.text, '12');
      expect(find.text('Add 1 Items (12 Units)'), findsOneWidget);
      await removeScreen(tester);
    });

    testWidgets('tapping a field that already has focus selects it again', (tester) async {
      await _pump(
        tester,
        () => const ProductSelectionScreen(partnerId: 59646, customerName: 'Test Distributor'),
      );
      final field = _qtyField.first;
      await tester.tap(field);
      await tester.pump();
      await _type(tester, field, '35');
      final controller = tester.widget<TextField>(field).controller!;
      expect(controller.text, '35');

      await tester.tap(field);
      await tester.pump();
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 2));
      await _type(tester, field, '4');
      expect(controller.text, '4');
      await removeScreen(tester);
    });
  });

  group('salesOrdersHeading', () {
    final now = DateTime(2026, 10, 28, 17, 5);

    test('no date filter means the latest orders, not only today', () {
      expect(salesOrdersHeading(null, null, now: now), 'Recent Sales Orders');
    });

    test('a filter on today alone says today', () {
      expect(
        salesOrdersHeading(DateTime(2026, 10, 28), DateTime(2026, 10, 28, 23, 59), now: now),
        "Today's Sales Orders",
      );
    });

    test('any other range is plain sales orders', () {
      expect(
        salesOrdersHeading(DateTime(2026, 10, 26), DateTime(2026, 10, 28), now: now),
        'Sales Orders',
      );
      expect(
        salesOrdersHeading(DateTime(2026, 10, 27), DateTime(2026, 10, 27), now: now),
        'Sales Orders',
      );
    });
  });

  testWidgets('team attendance empty message keeps off the screen edges', (tester) async {
    await _pump(tester, () => const AttendanceScreen());
    await tester.tap(find.text('Team'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    final message = find.text('Try other dates or team members.');
    expect(message, findsOneWidget);
    final box = tester.getRect(message);
    expect(box.left, greaterThanOrEqualTo(16));
    expect(box.right, lessThanOrEqualTo(360 - 16));
    expect(find.textContaining('Subordinates'), findsNothing);
    await removeScreen(tester);
  });
}
