import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/features/scraps/scrap_provider.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:secondary_sales/features/auth/screens/auth_gate.dart';
import 'package:secondary_sales/features/dashboard/dashboard_provider.dart';
import 'package:secondary_sales/features/dashboard/screens/home_dashboard_screen.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/services/push_notification_service.dart';
import 'package:secondary_sales/core/services/location_tracking_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Brings the background location service in line with the SERVER's attendance
/// state at launch, rather than trusting the persisted local flag (which can be
/// stale). Checked in on the server -> (re)start tracking with the latest
/// config; not checked in -> stop and clear the flag; unreachable -> fall back
/// to the local flag so a genuinely checked-in rep isn't dropped while offline.
Future<void> _reconcileLocationTracking(AuthProvider auth) async {
  final employeeId = auth.user?.employeeId ?? 0;
  if (employeeId == 0) {
    await LocationTrackingService.stop();
    return;
  }
  try {
    ApiService.instance.updateAccessToken(auth.accessToken);
    ApiService.instance.updateSessionId(auth.sessionId);
    ApiService.instance.updateEmployeeId(auth.employeeId);

    final res = await ApiService.instance.getAttendanceStatus(employeeId);
    if (res['success'] == true && res['data'] is Map) {
      final data = res['data'] as Map;
      if (data['is_checked_in'] == true) {
        await LocationTrackingService.start(
          intervalSeconds: data['location_tracking_interval'] ?? 1800,
          distanceMeters: data['location_tracking_distance'] ?? 30,
          syncIntervalSeconds: data['location_tracking_sync_interval'] ?? 3600,
          trackingType: data['location_tracking_type'] ?? 'both',
        );
      } else {
        // Server says not checked in: stop and clear the stale active flag.
        await LocationTrackingService.stop();
      }
      return;
    }
    // Ambiguous response — fall back to the local flag.
    await LocationTrackingService.resumeIfActive();
  } catch (_) {
    // Offline/unreachable: trust the local flag so a checked-in rep killed
    // mid-shift keeps tracking until the next successful reconcile.
    await LocationTrackingService.resumeIfActive();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initialize(navigatorKey: appNavigatorKey);
  await AppConstants.initialize();
  await LocationTrackingService.configure();

  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  ApiService.onTokenExpired = () async {
    final success = await authProvider.refreshSession();
    if (success) {
      return authProvider.accessToken;
    }
    return null;
  };

  // Reconcile background tracking with the SERVER's attendance state on launch.
  // The persisted "active" flag alone can go stale (app killed mid-shift, or an
  // interrupted checkout), and blindly trusting it makes the service buffer GPS
  // with no open attendance. When reachable, the server decides; offline, we
  // fall back to the flag so a genuinely checked-in rep keeps tracking.
  // Unawaited so a slow/failed network call never blocks startup.
  if (authProvider.isAuthenticated) {
    unawaited(_reconcileLocationTracking(authProvider));
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, PrimarySaleProvider>(
          create: (_) => PrimarySaleProvider(),
          update: (_, auth, sales) {
            final provider = sales ?? PrimarySaleProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            if (!auth.isAuthenticated) {
              provider.clearData(notify: false);
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransferProvider>(
          create: (_) => TransferProvider(),
          update: (_, auth, transfer) {
            final provider = transfer ?? TransferProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReturnProvider>(
          create: (_) => ReturnProvider(),
          update: (_, auth, returns) {
            final provider = returns ?? ReturnProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ScrapProvider>(
          create: (_) => ScrapProvider(),
          update: (_, auth, scrap) {
            final provider = scrap ?? ScrapProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, EmployeeProvider>(
          create: (_) => EmployeeProvider(),
          update: (_, auth, employee) {
            final provider = employee ?? EmployeeProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, RouteProvider>(
          create: (_) => RouteProvider(),
          update: (_, auth, route) {
            final provider = route ?? RouteProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, MyTeamProvider>(
          create: (_) => MyTeamProvider(),
          update: (_, auth, myTeam) {
            final provider = myTeam ?? MyTeamProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, auth, dashboard) {
            final provider = dashboard ?? DashboardProvider();
            provider.updateAuth(
              accessToken: auth.accessToken,
              sessionId: auth.sessionId,
              employeeId: auth.employeeId,
            );
            if (!auth.isAuthenticated) {
              provider.clearData(notify: false);
            }
            return provider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secondary Sales',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(authenticatedChild: HomeDashboardScreen()),
    );
  }
}
