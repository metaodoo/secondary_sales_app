import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/auth/logout_guard.dart';
import 'package:secondary_sales/features/auth/screens/connection_setup_screen.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/features/employees/screens/sales_officer_list_screen.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/location_buffer_screen.dart';
import 'package:secondary_sales/features/settings/screens/offline_data_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, this.onBack, this.onOpenMenu});

  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isRefreshingAccess = false;

  Future<void> _refreshAccessRights() async {
    if (_isRefreshingAccess) return;
    setState(() => _isRefreshingAccess = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().refreshAccessControl(throwOnError: true);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Access rights refreshed successfully.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to refresh access rights: ${e.toString().replaceAll('Exception: ', '')}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAccess = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?.employeeName ?? user?.name ?? 'Sales User';
    final role = user?.role ?? 'Primary Sales';
    final email = user?.name ?? '';

    final initials = initialsFromName(userName);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileAvatar(onTap: widget.onOpenMenu),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryTint,
                      border: Border.all(
                        color: AppColors.primaryTint,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  if (auth.canView(AppScreen.moduleAttendance)) ...[
                    _buildSettingItem(
                      icon: Icons.access_time_filled_outlined,
                      title: 'Attendance',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.borderMuted),
                  ],
                  _buildSettingItem(
                    icon: Icons.storage_outlined,
                    title: 'Location Buffer',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationBufferScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.sync_alt_outlined,
                    title: 'Offline & Outbox Data',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OfflineDataScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  if (auth.canView(AppScreen.moduleLeave)) ...[
                    _buildSettingItem(
                      icon: Icons.event_busy_outlined,
                      title: 'Leave Request',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaveDashboardScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.borderMuted),
                  ],
                  if (auth.canView(AppScreen.salesOfficerList)) ...[
                    _buildSettingItem(
                      icon: Icons.people_outline,
                      title: 'Sales Officers',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SalesOfficerListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.borderMuted),
                  ],
                  _buildSettingItem(
                    icon: Icons.security_update_good_outlined,
                    title: 'Refresh Access Rights',
                    subtitle: 'Sync latest permissions from server without re-login',
                    trailingWidget: _isRefreshingAccess
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                    onTap: _isRefreshingAccess ? () {} : _refreshAccessRights,
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.sync,
                    title: 'Sync Access Catalog',
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final result = await context
                            .read<AuthProvider>()
                            .syncAccessCatalog();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Access catalog synced '
                              '(+${result['added'] ?? 0}, ~${result['updated'] ?? 0}).',
                            ),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.cloud_outlined,
                    title: 'Server Connection',
                    subtitle: auth.baseUrl.isNotEmpty
                        ? (auth.dbName.isNotEmpty
                            ? '${auth.baseUrl} • ${auth.dbName}'
                            : auth.baseUrl)
                        : 'Not configured',
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: auth.baseUrl.isNotEmpty
                                ? AppColors.successSoft
                                : AppColors.borderMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: auth.baseUrl.isNotEmpty
                                  ? AppColors.success.withValues(alpha: 0.25)
                                  : AppColors.borderSoft,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: auth.baseUrl.isNotEmpty
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                auth.baseUrl.isNotEmpty ? 'Active' : 'Not set',
                                style: TextStyle(
                                  color: auth.baseUrl.isNotEmpty
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.borderSoft,
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConnectionSetupScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: 'English',
                    showChevron: false,
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: 'App Version',
                    trailing: 'v1.0.0',
                    showChevron: false,
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.logout,
                    title: 'Sign Out',
                    titleColor: Colors.red.shade700,
                    iconColor: Colors.red.shade700,
                    showChevron: false,
                    onTap: () async {
                      final signedOut = await logoutWithUnsyncedGuard(context);
                      if (signedOut && context.mounted) {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    Widget? trailingWidget,
    Color? titleColor,
    Color? iconColor,
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    Widget? trailingContent;
    if (trailingWidget != null) {
      trailingContent = trailingWidget;
    } else if (trailing != null) {
      trailingContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailing,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.borderSoft, size: 20),
          ],
        ],
      );
    } else if (showChevron) {
      trailingContent = const Icon(Icons.chevron_right, color: AppColors.borderSoft, size: 20);
    }

    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? const Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: trailingContent,
      onTap: onTap,
    );
  }
}
