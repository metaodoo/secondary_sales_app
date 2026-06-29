import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/services/push_notification_service.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/auth/screens/connection_setup_screen.dart';
import 'package:secondary_sales/features/auth/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authenticatedChild});

  final Widget authenticatedChild;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isConnectionConfigured) {
      return const ConnectionSetupScreen();
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.openPendingNotificationIfAny();
    });

    return authenticatedChild;
  }
}
