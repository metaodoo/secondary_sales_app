import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/auth/screens/connection_setup_screen.dart';
import 'package:secondary_sales/features/auth/screens/login_screen.dart';
import 'package:secondary_sales/features/dashboard/dashboard_provider.dart';
import 'package:secondary_sales/features/dashboard/screens/home_dashboard_screen.dart';
import 'package:secondary_sales/features/dashboard/screens/module_selection_screen.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/features/employees/screens/sales_officer_list_screen.dart';
import 'package:secondary_sales/features/hr/attendance_provider.dart';
import 'package:secondary_sales/features/hr/leave_provider.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/expense_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_request_screen.dart';
import 'package:secondary_sales/features/hr/screens/location_buffer_screen.dart';
import 'package:secondary_sales/features/hr/screens/personal_vehicle_trip_screen.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:secondary_sales/features/my_team/screens/my_team_screen.dart';
import 'package:secondary_sales/features/notifications/notice_provider.dart';
import 'package:secondary_sales/features/notifications/notification_provider.dart';
import 'package:secondary_sales/features/notifications/screens/notifications_screen.dart';
import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/features/routes/screens/routes_tab.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/scraps/scrap_provider.dart';
import 'package:secondary_sales/features/settings/screens/offline_data_screen.dart';
import 'package:secondary_sales/features/transfers/screens/create_virtual_location_screen.dart';
import 'package:secondary_sales/features/transfers/screens/create_virtual_transfer_screen.dart';
import 'package:secondary_sales/features/transfers/screens/virtual_transfer_list_screen.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';

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

  // Company phones are entry-level 720p, e.g. Oppo A12 (720x1520) and
  // A15/A16 (720x1600): 360 dp wide at 2x. Personal phones are larger.
  // 320 wide is a stricter floor.
  const sizes = <(String, Size, double)>[
    ('narrow 320x640', Size(320, 640), 1.0),
    ('720p 360x640', Size(360, 640), 1.0),
    ('720p A12 360x760', Size(360, 760), 1.0),
    ('720p A15/A16 360x800', Size(360, 800), 1.0),
    ('720p landscape 640x360', Size(640, 360), 1.0),
    ('720p A15/A16 landscape 800x360', Size(800, 360), 1.0),
    ('720p large text 360x800 x1.3', Size(360, 800), 1.3),
    ('personal phone 393x873', Size(393, 873), 1.0),
  ];

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
    await _loadInterFont();
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

  for (final (name, build) in screens) {
    for (final (label, size, textScale) in sizes) {
      testWidgets('$name fits on $label', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        // Never disposed: the app keeps its providers for its whole life,
        // and screens may finish loading after the test ends.
        final auth = AuthProvider();
        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            // Point at the widget in lib/ that overflowed.
            final where = RegExp(r'lib/[\w/]+\.dart:\d+')
                .firstMatch(details.toString())
                ?.group(0);
            overflows.add('${text.split('\n').first} at $where');
          }
        };
        try {
          await http.runWithClient(() async {
            await tester.pumpWidget(MultiProvider(
              providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: PrimarySaleProvider()),
          ChangeNotifierProvider.value(value: TransferProvider()),
          ChangeNotifierProvider.value(value: ReturnProvider()),
          ChangeNotifierProvider.value(value: ScrapProvider()),
          ChangeNotifierProvider.value(value: EmployeeProvider()),
          ChangeNotifierProvider.value(value: RouteProvider()),
          ChangeNotifierProvider.value(value: ModernTradeProvider()),
          ChangeNotifierProvider.value(value: MtReturnProvider()),
          ChangeNotifierProvider.value(value: MyTeamProvider()),
          ChangeNotifierProvider.value(value: DashboardProvider()),
          ChangeNotifierProvider.value(value: NotificationProvider()),
          ChangeNotifierProvider.value(value: NoticeProvider()),
          ChangeNotifierProvider.value(value: LeaveProvider(auth)),
          ChangeNotifierProvider.value(value: AttendanceProvider(auth)),
              ],
              child: MaterialApp(
                theme: buildAppTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: build(),
              ),
            ));
            for (var i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 200));
            }
          }, () => client);
        } finally {
          FlutterError.onError = previous;
        }
        // Leave timers and streams of the screen behind.
        await tester.pumpWidget(const SizedBox());
        expect(overflows, isEmpty, reason: overflows.join('; '));
      });
    }
  }
}

/// Loads the app's font (Inter) under the names google_fonts uses, so text
/// is measured as on a phone. The test font draws every letter as a full
/// square and reports overflows that real text does not have. Without the
/// file the stricter test font stays in use.
Future<void> _loadInterFont() async {
  final file = [
    Platform.environment['INTER_FONT'],
    '/usr/local/share/fonts/i/Inter_VariableFont_opsz,wght.ttf',
    '/usr/share/fonts/truetype/inter/Inter_VariableFont_opsz,wght.ttf',
  ].whereType<String>().map(File.new).where((f) => f.existsSync()).firstOrNull;
  if (file == null) return;
  final bytes = file.readAsBytesSync().buffer.asByteData();
  for (final weight in ['regular', for (var w = 100; w <= 900; w += 100) '$w']) {
    final loader = FontLoader('Inter_$weight')..addFont(Future.value(bytes));
    await loader.load();
  }
}
