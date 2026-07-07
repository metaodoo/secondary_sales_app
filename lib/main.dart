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
import 'package:secondary_sales/features/dashboard/screens/module_selection_screen.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/services/push_notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initialize(navigatorKey: appNavigatorKey);
  await AppConstants.initialize();

  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  ApiService.onTokenExpired = () async {
    final success = await authProvider.refreshSession();
    if (success) {
      return authProvider.accessToken;
    }
    return null;
  };

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
      home: const AuthGate(authenticatedChild: ModuleSelectionScreen()),
    );
  }
}
