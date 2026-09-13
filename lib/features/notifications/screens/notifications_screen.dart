import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/notifications/app_notice.dart';
import 'package:secondary_sales/data/models/notifications/app_notification.dart';
import 'package:secondary_sales/features/notifications/notification_format.dart';
import 'package:secondary_sales/features/notifications/notification_provider.dart';
import 'package:secondary_sales/features/notifications/notice_provider.dart';
import 'package:secondary_sales/features/notifications/screens/notice_detail_screen.dart';
import 'package:secondary_sales/features/notifications/screens/notification_detail_screen.dart';

/// The unified communication center:
/// - Tab 1: Personal direct notifications (workflow approvals, visits, etc.)
/// - Tab 2: Notice Board (channel-based announcements, memos, circulars)
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().refresh();
        context.read<NoticeProvider>().refresh();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifUnread = context.watch<NotificationProvider>().unreadCount;
    final noticeUnread = context.watch<NoticeProvider>().unreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Notifications & Notices',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Notifications'),
                  if (notifUnread > 0) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: notifUnread),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.campaign_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Notice Board'),
                  if (noticeUnread > 0) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: noticeUnread),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _NotificationsTab(),
          _NoticeBoardTab(),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: Personal Notifications
// -----------------------------------------------------------------------------
class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: !provider.onlyUnread,
                    onSelected: () => provider.setOnlyUnread(false),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Unread',
                    count: provider.unreadCount,
                    isSelected: provider.onlyUnread,
                    onSelected: () => provider.setOnlyUnread(true),
                  ),
                  const Spacer(),
                  if (provider.unreadCount > 0)
                    TextButton(
                      onPressed: provider.markAllRead,
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: _buildList(provider),
              ),
            ),
          ],
        );
      },
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
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
            child: _EmptyState(
              icon: Icons.notifications_none_outlined,
              title: provider.onlyUnread
                  ? 'No unread notifications'
                  : 'No notifications yet',
              subtitle: provider.onlyUnread
                  ? 'You are all caught up.'
                  : 'Important workflow updates and alerts will appear here.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length + (provider.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final notif = items[index];
        return _NotificationCard(
          notification: notif,
          onTap: () => _openDetail(notif),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: Notice Board
// -----------------------------------------------------------------------------
class _NoticeBoardTab extends StatefulWidget {
  const _NoticeBoardTab();

  @override
  State<_NoticeBoardTab> createState() => _NoticeBoardTabState();
}

class _NoticeBoardTabState extends State<_NoticeBoardTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      context.read<NoticeProvider>().loadMore();
    }
  }

  Future<void> _openNotice(AppNotice notice) async {
    context.read<NoticeProvider>().markNoticeRead(notice.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(notice: notice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoticeProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Channels horizontal chips
            _buildChannelChips(provider),

            // Filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All Notices',
                    isSelected: !provider.onlyUnread,
                    onSelected: () => provider.setOnlyUnread(false),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Unread',
                    count: provider.unreadCount,
                    isSelected: provider.onlyUnread,
                    onSelected: () => provider.setOnlyUnread(true),
                  ),
                  const Spacer(),
                  if (provider.selectedChannelId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark channel read'),
                      onPressed: () =>
                          provider.markChannelRead(provider.selectedChannelId!),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: _buildNoticeList(provider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChannelChips(NoticeProvider provider) {
    final channels = provider.channels;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: channels.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAll = provider.selectedChannelId == null;
            return ChoiceChip(
              label: const Text('All Channels'),
              selected: isAll,
              onSelected: (_) => provider.selectChannel(null),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isAll ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            );
          }

          final ch = channels[index - 1];
          final isSelected = provider.selectedChannelId == ch.id;

          return ChoiceChip(
            avatar: Icon(
              Icons.tag,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ch.name),
                if (ch.unreadCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${ch.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            selected: isSelected,
            onSelected: (_) => provider.selectChannel(ch.id),
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoticeList(NoticeProvider provider) {
    if (provider.isLoading && provider.notices.isEmpty) {
      return ListView(
        children: const [LoadingState(message: 'Loading notices...')],
      );
    }

    final items = provider.notices;
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
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
            child: _EmptyState(
              icon: Icons.campaign_outlined,
              title: provider.onlyUnread
                  ? 'No unread notices'
                  : 'No notices published',
              subtitle: provider.onlyUnread
                  ? 'All notices in subscribed channels are marked as read.'
                  : 'Company and department circulars will appear here when posted.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: items.length + (provider.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final notice = items[index];
        return _NoticeCard(
          notice: notice,
          onTap: () => _openNotice(notice),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Card & Helper Widgets
// -----------------------------------------------------------------------------
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.onTap,
  });

  final AppNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeStr = notice.createdAt != null
        ? DateFormat('MMM d • h:mm a').format(notice.createdAt!)
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notice.isRead
              ? AppColors.surface
              : AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notice.isRead
                ? AppColors.borderSoft
                : AppColors.primary.withValues(alpha: 0.3),
            width: notice.isRead ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel & Date & Unread Dot
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${notice.channelName}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                if (!notice.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Subject / Title (if present)
            if (notice.subject.isNotEmpty) ...[
              Text(
                notice.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Body Snippet
            Text(
              notice.plainTextBody.isNotEmpty
                  ? notice.plainTextBody
                  : 'Notice content',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Author & Attachment Badge Row
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: notice.authorAvatarUrl != null
                      ? NetworkImage(
                          notice.authorAvatarUrl!.startsWith('http')
                              ? notice.authorAvatarUrl!
                              : '${AppConstants.baseUrl}${notice.authorAvatarUrl}',
                        )
                      : null,
                  child: notice.authorAvatarUrl == null
                      ? Text(
                          notice.authorName.isNotEmpty
                              ? notice.authorName[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    notice.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (notice.hasAttachments)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${notice.attachments.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'approval':
      case 'leave':
        return Icons.fact_check_outlined;
      case 'order':
      case 'sale':
        return Icons.shopping_bag_outlined;
      case 'delivery':
      case 'transfer':
        return Icons.local_shipping_outlined;
      case 'attendance':
        return Icons.access_time_outlined;
      case 'warning':
      case 'alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final iconData = _iconForType(notification.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.borderSoft,
            width: isUnread ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
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
                            color: AppColors.textPrimary,
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (notification.createdAt != null)
                        Text(
                          notificationRelativeTime(notification.createdAt),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
