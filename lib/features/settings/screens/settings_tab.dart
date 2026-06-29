import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/employees/screens/sales_officer_list_screen.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_request_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?.employeeName ?? user?.name ?? 'Sales User';
    final role = user?.role ?? 'Primary Sales';
    final email = user?.name ?? '';

    // Generate initials for profile icon
    String initials = 'U';
    if (userName.isNotEmpty) {
      final parts = userName.trim().split(' ');
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: onBack,
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
                  _buildSettingItem(
                    icon: Icons.event_busy_outlined,
                    title: 'Leave Request',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaveRequestScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
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
                  _buildSettingItem(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: 'English',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: 'App Version',
                    trailing: 'v1.0.0',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.borderMuted),
                  _buildSettingItem(
                    icon: Icons.logout,
                    title: 'Log Out',
                    titleColor: Colors.red.shade700,
                    iconColor: Colors.red.shade700,
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
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
    String? trailing,
    Color? titleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
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
      trailing: trailing != null
          ? Text(
              trailing,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            )
          : const Icon(Icons.chevron_right, color: AppColors.borderSoft),
      onTap: onTap,
    );
  }
}
