import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/settings/screens/offline_data_screen.dart';

/// Signs the user out unless offline documents are still waiting to sync.
///
/// When unsynced operations exist, explains why sign-out is blocked and offers
/// the Offline Data screen, where they can be synced or reviewed.
/// [onBeforeLogout] runs only when sign-out goes ahead (e.g. to close a drawer).
/// Returns true when the user was signed out.
Future<bool> logoutWithUnsyncedGuard(
  BuildContext context, {
  VoidCallback? onBeforeLogout,
}) async {
  final auth = context.read<AuthProvider>();
  final unsyncedCount = await auth.unsyncedOperationCount();
  if (!context.mounted) return false;

  if (unsyncedCount > 0) {
    final openOfflineData = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsynced Documents'),
        content: Text(
          'You have $unsyncedCount document${unsyncedCount == 1 ? '' : 's'} '
          'that ${unsyncedCount == 1 ? 'has' : 'have'} not been synced to the server. '
          'Sync them before logging out, or they will be stranded on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('View Offline Data'),
          ),
        ],
      ),
    );
    if (openOfflineData == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OfflineDataScreen()),
      );
    }
    return false;
  }

  onBeforeLogout?.call();
  return auth.logout();
}
