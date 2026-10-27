import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/screens/connection_setup_screen.dart';
import 'package:secondary_sales/features/auth/screens/login_screen.dart';
import 'package:secondary_sales/features/dashboard/screens/home_dashboard_screen.dart';
import 'package:secondary_sales/features/dashboard/screens/module_selection_screen.dart';
import 'package:secondary_sales/features/employees/screens/sales_officer_list_screen.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/expense_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_request_screen.dart';
import 'package:secondary_sales/features/hr/screens/location_buffer_screen.dart';
import 'package:secondary_sales/features/hr/screens/personal_vehicle_trip_screen.dart';
import 'package:secondary_sales/features/my_team/screens/my_team_screen.dart';
import 'package:secondary_sales/features/notifications/screens/notifications_screen.dart';
import 'package:secondary_sales/features/routes/screens/routes_tab.dart';
import 'package:secondary_sales/features/settings/screens/offline_data_screen.dart';
import 'package:secondary_sales/features/transfers/screens/create_virtual_location_screen.dart';
import 'package:secondary_sales/features/transfers/screens/create_virtual_transfer_screen.dart';
import 'package:secondary_sales/features/transfers/screens/virtual_transfer_list_screen.dart';

import 'support/layout_harness.dart';

/// Renders screens at small, landscape and large-text sizes and records
/// layout overflows (the yellow-black stripes on a device).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Every request gets an empty success, so screens render their normal
  // (empty) state without a server.
  final client = MockClient((request) async => http.Response(
        jsonEncode({'jsonrpc': '2.0', 'result': {'success': true, 'data': []}}),
        200,
      ));

  final screens = <(String, Widget Function())>[
    ('AttendanceScreen', () => const AttendanceScreen()),
    ('ConnectionSetupScreen', () => const ConnectionSetupScreen()),
    ('CreateVirtualLocationScreen', () => const CreateVirtualLocationScreen()),
    ('CreateVirtualTransferScreen', () => const CreateVirtualTransferScreen()),
    ('ExpenseDashboardScreen', () => const ExpenseDashboardScreen()),
    ('HomeDashboardScreen', () => const HomeDashboardScreen()),
    ('LeaveDashboardScreen', () => const LeaveDashboardScreen()),
    ('LeaveRequestScreen', () => const LeaveRequestScreen()),
    ('LocationBufferScreen', () => const LocationBufferScreen()),
    ('LoginScreen', () => const LoginScreen()),
    ('ModuleSelectionScreen', () => const ModuleSelectionScreen()),
    ('MyTeamScreen', () => const MyTeamScreen()),
    ('NotificationsScreen', () => const NotificationsScreen()),
    ('OfflineDataScreen', () => const OfflineDataScreen()),
    ('PersonalVehicleTripScreen', () => const PersonalVehicleTripScreen()),
    ('RoutesTab', () => const RoutesTab()),
    ('SalesOfficerListScreen', () => const SalesOfficerListScreen()),
    ('VirtualTransferListScreen', () => const VirtualTransferListScreen()),
  ];

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('responsive_');
    await databaseFactory.setDatabasesPath(dir.path);
    await loadInterFont();
  });

  group('Menu tiles', () {
    Future<List<Rect>> tiles(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => GridView(
            padding: const EdgeInsets.all(16),
            gridDelegate: ssTileGridDelegate(context, height: 124),
            children: [for (var i = 0; i < 7; i++) Container(key: ValueKey(i))],
          ),
        ),
      ));
      return [for (var i = 0; i < 4; i++) tester.getRect(find.byKey(ValueKey(i)))];
    }

    testWidgets('keep their height and gain columns in landscape', (tester) async {
      // A 720p company phone (360 dp wide).
      final portrait = await tiles(tester, const Size(360, 640));
      final landscape = await tiles(tester, const Size(640, 360));

      expect(portrait.first.height, 124);
      expect(landscape.first.height, 124);
      // Two per row held upright, three held sideways.
      expect(portrait[2].top, greaterThan(portrait[0].top));
      expect(landscape[2].top, landscape[0].top);
      // A full row still fits on the short landscape screen.
      expect(landscape.first.bottom, lessThan(360));
    });
  });

  final a11yBaseline = AccessibilityBaseline('screens');
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
