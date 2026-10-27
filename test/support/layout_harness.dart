import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/dashboard/dashboard_provider.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/features/hr/attendance_provider.dart';
import 'package:secondary_sales/features/hr/leave_provider.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:secondary_sales/features/notifications/notice_provider.dart';
import 'package:secondary_sales/features/notifications/notification_provider.dart';
import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/scraps/scrap_provider.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';

/// Screen sizes to check, as (label, size in dp, text scale).
///
/// Text goes up to 1.5x for now; WCAG 1.4.4 and Android allow 2x, the later
/// goal.
///
/// Company phones are entry-level 720p, e.g. Oppo A12 (720x1520) and
/// A15/A16 (720x1600): 360 dp wide at 2x. Personal phones are larger.
/// 320 wide is a stricter floor.
const layoutSizes = <(String, Size, double)>[
  ('narrow 320x640', Size(320, 640), 1.0),
  ('720p 360x640', Size(360, 640), 1.0),
  ('720p A12 360x760', Size(360, 760), 1.0),
  ('720p A15/A16 360x800', Size(360, 800), 1.0),
  ('720p landscape 640x360', Size(640, 360), 1.0),
  ('720p A15/A16 landscape 800x360', Size(800, 360), 1.0),
  ('720p large text 360x800 x1.3', Size(360, 800), 1.3),
  ('720p larger text 360x800 x1.5', Size(360, 800), 1.5),
  ('personal phone 393x873', Size(393, 873), 1.0),
];

/// What one rendering of a screen found.
class ScreenReport {
  /// Layout overflows (the yellow-black stripes on a device), each with the
  /// line in lib/ that overflowed.
  final overflows = <String>[];

  /// Accessibility guideline failures, by check name. Empty unless asked.
  final accessibility = <String, String>{};
}

/// Accessibility checks, as Flutter ships them (the same rules as Android's
/// Accessibility Test Framework): 48 dp touch targets, a label on every
/// tappable element, and readable text contrast.
final accessibilityChecks = <String, AccessibilityGuideline>{
  'tap_target_48dp': androidTapTargetGuideline,
  'tap_target_label': labeledTapTargetGuideline,
  'text_contrast': textContrastGuideline,
};

/// Renders [build] at [size] and [textScale] inside the app's providers and
/// theme, with every request answered by [client], and reports overflows.
/// With [accessibility], also runs [accessibilityChecks] on the screen.
Future<ScreenReport> checkScreen(
  WidgetTester tester,
  Widget Function() build, {
  required Size size,
  required double textScale,
  required http.Client client,
  bool accessibility = false,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final semantics = accessibility ? tester.ensureSemantics() : null;
  // No GPS in tests: the location plugin reports location off, so screens
  // that track GPS show their normal "location off" state.
  const gps = MethodChannel('flutter.baseflow.com/geolocator');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(gps, (call) async {
    return switch (call.method) {
      'isLocationServiceEnabled' => false,
      'checkPermission' => 0, // denied
      _ => null,
    };
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(gps, null));
  // Never disposed: the app keeps its providers for its whole life, and
  // screens may finish loading after the test ends.
  final auth = AuthProvider();
  final report = ScreenReport();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      final where =
          RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString())?.group(0);
      report.overflows.add('${text.split('\n').first} at $where');
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
    }, () => _NoFontDownloads(client));
    if (accessibility) {
      for (final MapEntry(key: name, value: check) in accessibilityChecks.entries) {
        final result = await check.evaluate(tester);
        if (!result.passed) report.accessibility[name] = result.reason ?? '';
      }
    }
  } finally {
    FlutterError.onError = previous;
    semantics?.dispose();
  }
  // Remove the screen and let its timers run out (some one-shot timers in
  // the app last longer than a few seconds), so they do not fail the test
  // after it ends. Test time is fake, so this costs nothing.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 5));
  return report;
}

/// Known accessibility problems per screen: a baseline, as large teams keep
/// for lint (Android Lint's baseline.xml). Known problems are listed in
/// test/fixtures/layout/a11y_baseline_<suite>.json for review but do not
/// fail; a new problem fails, and so does a fixed problem still listed, so
/// the list can only shrink. Run with UPDATE_A11Y_BASELINE=1 to rewrite it.
class AccessibilityBaseline {
  AccessibilityBaseline(this.suite);

  final String suite;

  static final _update = Platform.environment['UPDATE_A11Y_BASELINE'] == '1';

  File get _file => File('test/fixtures/layout/a11y_baseline_$suite.json');

  late final Map<String, dynamic> _known = _file.existsSync()
      ? jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>
      : {};

  final _found = <String, Map<String, String>>{};

  void check(String screen, ScreenReport report) {
    final failed = report.accessibility;
    if (_update) {
      // Keep the start of each reason: enough to find the element.
      _found[screen] = {
        for (final MapEntry(:key, :value) in failed.entries)
          key: value.split('\n').take(3).join(' | '),
      };
      return;
    }
    final known = (_known[screen] as Map<String, dynamic>? ?? {}).keys.toSet();
    final added = failed.keys.where((c) => !known.contains(c)).toList();
    final fixed = known.where((c) => !failed.containsKey(c)).toList();
    expect(
      added,
      isEmpty,
      reason: 'New accessibility problems on $screen:\n'
          '${added.map((c) => '$c: ${failed[c]}').join('\n')}',
    );
    expect(
      fixed,
      isEmpty,
      reason: '$screen now passes $fixed. Remove it from ${_file.path} '
          '(run with UPDATE_A11Y_BASELINE=1).',
    );
  }

  /// Writes the baseline in update mode; call from tearDownAll.
  void save() {
    if (!_update) return;
    final sorted = {
      for (final name in _found.keys.toList()..sort())
        if (_found[name]!.isNotEmpty) name: _found[name],
    };
    _file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
  }
}

/// Loads the app's font (Inter) under the names google_fonts uses, so text
/// is measured as on a phone. The test font draws every letter as a full
/// square and reports overflows that real text does not have. Without the
/// file the stricter test font stays in use.
Future<void> loadInterFont() async {
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

/// Passes requests to [_inner], except google_fonts downloads, which never
/// answer: [loadInterFont] already provides the font, and a fake answer
/// fails the font checksum inside the test.
class _NoFontDownloads extends http.BaseClient {
  _NoFontDownloads(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      request.url.host == 'fonts.gstatic.com'
          ? Completer<http.StreamedResponse>().future
          : _inner.send(request);
}
