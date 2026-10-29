import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/van_loading/screens/van_load_form_screen.dart';

import 'support/layout_harness.dart';

const _noDistributor = 'Employee is not assigned to any distributor.';

/// What /van_loading/targets answers. The app's API client keeps the first
/// HTTP client it is given, so every test shares [_client] and only changes
/// this.
Map<String, dynamic> _targets = {};

/// Staging's answers for an employee with no distributor, recorded on
/// 2026-10-28, except for the targets, which each test sets.
final _client = MockClient((request) async {
  final path = request.url.path;
  final Map<String, dynamic> result;
  if (path.endsWith('/van_loading/targets')) {
    result = _targets;
  } else if (path.endsWith('/virtual-transfers/prepare')) {
    result = {
      'success': true,
      'data': {
        'employee': {'id': 208, 'name': 'Md Akteruzzaman (9121)'},
        'distributor': null,
        'source_location': null,
        'destination_locations': [],
      },
    };
  } else {
    result = {'success': true, 'data': []};
  }
  return http.Response.bytes(
    utf8.encode(jsonEncode({'jsonrpc': '2.0', 'result': result})),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

/// Signed in as employee 208: the form asks for targets only then.
class _SignedIn extends AuthProvider {
  @override
  int? get employeeId => 208;
}

Future<void> _pump(WidgetTester tester) => pumpAppScreen(
      tester,
      () => ChangeNotifierProvider<AuthProvider>.value(
        value: _SignedIn(),
        child: const VanLoadFormScreen(),
      ),
      size: const Size(360, 800),
      textScale: 1.0,
      client: _client,
    );

ElevatedButton _validate(WidgetTester tester) => tester.widget<ElevatedButton>(
      find.ancestor(of: find.text('Validate'), matching: find.byType(ElevatedButton)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    await loadMaterialIcons();
    await loadInterFont();
  });

  testWidgets('shows why the van could not be loaded', (tester) async {
    _targets = {'success': false, 'error': 'validation_error', 'message': _noDistributor};
    await _pump(tester);

    expect(find.text(_noDistributor), findsOneWidget);
    expect(_validate(tester).onPressed, isNull);
    await removeScreen(tester);
  });

  testWidgets('a van with targets shows no error and can be validated', (tester) async {
    _targets = {'success': true, 'data': []};
    await _pump(tester);

    expect(find.text(_noDistributor), findsNothing);
    expect(_validate(tester).onPressed, isNotNull);
    await removeScreen(tester);
  });
}
