import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/notifications/app_notification.dart';
import 'package:secondary_sales/features/notifications/notification_format.dart';
import 'package:secondary_sales/features/notifications/notification_provider.dart';
import 'package:secondary_sales/features/notifications/screens/notification_detail_screen.dart';

/// The notification center: the caller's notifications, newest first, with an
/// All/Unread filter, pull-to-refresh, infinite scroll, and "mark all read".
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  Future<void> _openDetail(AppNotification notification) async {
    context.read<NotificationProvider>().markRead(notification.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notification: notification),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: provider.markAllRead,
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _FilterBar(
                onlyUnread: provider.onlyUnread,
                onChanged: provider.setOnlyUnread,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: _buildList(provider),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(NotificationProvider provider) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return ListView(
        children: const [LoadingState(message: 'Loading notifications...')],
      );
    }

    final items = provider.notifications;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorPanel(provider.error!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
            child: _EmptyNotifications(onlyUnread: provider.onlyUnread),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (provider.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final notification = items[index];
        return _NotificationCard(
          notification: notification,
          onTap: () => _openDetail(notification),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.onlyUnread, required this.onChanged});

  final bool onlyUnread;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: AppColors.surface,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: !onlyUnread,
            onSelected: (_) => onChanged(false),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Unread'),
            selected: onlyUnread,
            onSelected: (_) => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Material(
      color: unread ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 5, right: 10),
                decoration: BoxDecoration(
                  color: unread ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.bold : FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notificationRelativeTime(notification.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.onlyUnread});

  final bool onlyUnread;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.notifications_off_outlined,
          size: 48,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 12),
        Text(
          onlyUnread ? 'No unread notifications.' : 'No notifications yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
