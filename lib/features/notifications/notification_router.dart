import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/notifications/app_notification.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';
import 'package:secondary_sales/features/hr/leave_provider.dart';
import 'package:secondary_sales/features/hr/screens/expense_details_sheet.dart';
import 'package:secondary_sales/features/hr/screens/leave_details_sheet.dart';
import 'package:secondary_sales/features/sales/screens/order_detail_screen.dart';

/// Opens the screen for a given record reference.
typedef NotificationOpener =
    Future<void> Function(NavigatorState navigator, NotificationLink link);

/// Maps a notification's generic record reference ([NotificationLink.model]) to
/// the right in-app screen. This is the single place both the push-tap handler
/// and the in-app "Open record" button route through, so behaviour is identical.
///
/// Adding a new record type is one registry entry (plus any extra field its
/// screen needs carried in the notification payload). Models without a handler
/// fall back to the notification detail card (no navigation).
class NotificationRouter {
  NotificationRouter._();

  static final Map<String, NotificationOpener> _registry = {
    'sale.order': (navigator, link) async {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            orderId: link.recordId,
            fallbackName: link.name ?? 'Sale Order #${link.recordId}',
            saleType: link.saleType ?? 'primary',
          ),
        ),
      );
    },
    // LeaveProvider/ExpenseProvider are created per-screen rather than in the
    // global MultiProvider, so a deep link builds its own from the (global)
    // AuthProvider instead of reading one that is not in this subtree.
    'hr.leave': (navigator, link) async {
      final context = navigator.context;
      final provider = LeaveProvider(context.read<AuthProvider>());
      final leave = await provider.fetchLeaveById(link.recordId);
      if (!context.mounted) return;
      if (leave == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this leave request.')),
        );
        return;
      }
      LeaveDetailsSheet.show(context, provider, leave);
    },
    'hr.expense.sheet': (navigator, link) async {
      final context = navigator.context;
      // The sheet fetches its own details in initState from the id, so a
      // summary carrying only the id is enough to open it.
      ExpenseDetailsSheet.show(
        context,
        {'id': link.recordId},
        provider: ExpenseProvider(context.read<AuthProvider>()),
      );
    },
  };

  /// True when [link] points at a model that has a registered screen.
  static bool canOpen(NotificationLink? link) =>
      link != null && _registry.containsKey(link.model);

  /// Opens the record [link] points at. Returns false when there is no
  /// registered handler, so the caller can fall back to the detail card.
  static Future<bool> open(
    NavigatorState? navigator,
    NotificationLink? link,
  ) async {
    if (navigator == null || link == null) return false;
    final opener = _registry[link.model];
    if (opener == null) return false;
    await opener(navigator, link);
    return true;
  }

  /// Model-aware label for the "open record" button.
  static String openLabel(NotificationLink link) {
    switch (link.model) {
      case 'sale.order':
        return 'Open Sale Order';
      case 'hr.leave':
        return 'Open Leave Request';
      case 'hr.expense.sheet':
        return 'Open Expense Report';
      default:
        return 'Open Record';
    }
  }
}
