import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/app/navigation/app_shell.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/expense_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/my_team/screens/my_team_screen.dart';

/// One entry in the top-level module launcher.
class ModuleLauncherItem {
  const ModuleLauncherItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// The access-gated list of top-level modules (Primary, Secondary, Attendance,
/// Leave, Expense, My Team) with their navigation. Single definition shared by
/// the home landing screen's launcher and the in-shell floating launcher.
///
/// NOTE: the home dashboard still has its own inline copy of this list; keep the
/// two in sync until that screen is migrated onto this helper.
List<ModuleLauncherItem> buildTopLevelModuleItems(BuildContext context) {
  final auth = context.read<AuthProvider>();

  void open(Widget screen) {
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  return [
    if (auth.canAccessPrimarySales)
      ModuleLauncherItem(
        title: 'Primary',
        icon: Icons.factory_outlined,
        color: AppColors.primaryStrong,
        onTap: () => open(const AppShell(moduleType: 'primary')),
      ),
    if (auth.canAccessSecondarySales)
      ModuleLauncherItem(
        title: 'Secondary',
        icon: Icons.storefront_outlined,
        color: const Color(0xFF10B981),
        onTap: () => open(const AppShell(moduleType: 'secondary')),
      ),
    if (auth.canView(AppScreen.moduleAttendance))
      ModuleLauncherItem(
        title: 'Attendance',
        icon: Icons.access_time_filled_outlined,
        color: const Color(0xFFF59E0B),
        onTap: () => open(const AttendanceScreen()),
      ),
    if (auth.canView(AppScreen.moduleLeave))
      ModuleLauncherItem(
        title: 'Leave Request',
        icon: Icons.event_busy_outlined,
        color: const Color(0xFFEF4444),
        onTap: () => open(const LeaveDashboardScreen()),
      ),
    if (auth.canView(AppScreen.moduleExpense))
      ModuleLauncherItem(
        title: 'Expense',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF6366F1),
        onTap: () => open(const ExpenseDashboardScreen()),
      ),
    if (auth.canView(AppScreen.moduleMyTeam))
      ModuleLauncherItem(
        title: 'My Team',
        icon: Icons.group_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: () => open(const MyTeamScreen()),
      ),
  ];
}

/// Bottom-sheet picker of the top-level modules. Tapping a tile closes the sheet
/// and navigates to that module.
Future<void> showModuleLauncherSheet(BuildContext context) {
  final items = buildTopLevelModuleItems(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.78;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x220F172A),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.borderSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Open module',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Jump straight into the part of the app you need.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < items.length; i++) ...[
                      _ModulePickerTile(
                        item: items[i],
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            items[i].onTap();
                          });
                        },
                      ),
                      if (i != items.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Pill-shaped floating button that opens the module launcher sheet. Pass
/// [visible] to animate it in/out (e.g. tied to scroll on the home screen); it
/// defaults to always visible for use inside a shell.
class ModuleLauncherFab extends StatelessWidget {
  const ModuleLauncherFab({super.key, this.visible = true});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : const Offset(0, 1.2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: Material(
            color: AppColors.primaryStrong,
            borderRadius: BorderRadius.circular(999),
            elevation: 8,
            child: InkWell(
              onTap: () => showModuleLauncherSheet(context),
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apps_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Open module',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModulePickerTile extends StatelessWidget {
  const _ModulePickerTile({required this.item, required this.onTap});

  final ModuleLauncherItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
