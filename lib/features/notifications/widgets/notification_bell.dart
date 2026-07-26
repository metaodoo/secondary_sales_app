import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/notifications/notification_provider.dart';
import 'package:secondary_sales/features/notifications/screens/notifications_screen.dart';

/// App-bar bell with an unread badge. Opens the notification center and
/// refreshes the badge on return. Drop into any `AppBar.actions`.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.color = AppColors.textPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final count = provider.unreadCount;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            if (context.mounted) {
              context.read<NotificationProvider>().refreshUnreadCount();
            }
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none_rounded, color: color, size: 26),
              if (count > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
