import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/app/navigation/app_shell.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/features/settings/screens/settings_tab.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/expense_dashboard_screen.dart';
import 'package:secondary_sales/features/my_team/screens/my_team_screen.dart';

class ModuleSelectionScreen extends StatelessWidget {
  const ModuleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Module picker cards are gated by the backend access config (which
    // ss.module records the group is assigned).
    final auth = context.watch<AuthProvider>();
    final canAccessPrimary = auth.canAccessPrimarySales;
    final canAccessSecondary = auth.canAccessSecondarySales;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Sales & Distribution',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Select Module',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your operational flow to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 48),

              if (canAccessPrimary) ...[
                _buildLargeModuleCard(
                  context,
                  title: 'Primary',
                  description:
                      'Sales, dealers, delivery, return delivery, and return scrap.',
                  icon: Icons.factory_outlined,
                  color: AppColors.primaryStrong,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppShell(moduleType: 'primary'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              if (canAccessSecondary)
                _buildLargeModuleCard(
                  context,
                  title: 'Secondary',
                  description:
                      'Sales, routes, outlets, van loading, delivery, and returns.',
                  icon: Icons.storefront_outlined,
                  color: const Color(
                    0xFF10B981,
                  ), // Emerald green to distinguish
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppShell(moduleType: 'secondary'),
                      ),
                    );
                  },
                ),
              if (auth.canView(AppScreen.moduleAttendance)) ...[
                const SizedBox(height: 24),
                _buildLargeModuleCard(
                  context,
                  title: 'Attendance',
                  description: 'Manage your daily check-ins and check-outs.',
                  icon: Icons.access_time_filled_outlined,
                  color: const Color(0xFFF59E0B), // Amber color
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AttendanceScreen(),
                      ),
                    );
                  },
                ),
              ],
              if (auth.canView(AppScreen.moduleLeave)) ...[
                const SizedBox(height: 24),
                _buildLargeModuleCard(
                  context,
                  title: 'Leave Request',
                  description: 'Apply for leaves and track your requests.',
                  icon: Icons.event_busy_outlined,
                  color: const Color(0xFFEF4444), // Red color
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaveDashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
              if (auth.canView(AppScreen.moduleExpense)) ...[
                const SizedBox(height: 24),
                _buildLargeModuleCard(
                  context,
                  title: 'Expense',
                  description: 'Submit business expenses and track approvals.',
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFF6366F1), // Indigo color
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExpenseDashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
              if (auth.canView(AppScreen.moduleMyTeam)) ...[
                const SizedBox(height: 24),
                _buildLargeModuleCard(
                  context,
                  title: 'My Team',
                  description: 'Track subordinate checkpoints and attendance shifts.',
                  icon: Icons.group_outlined,
                  color: const Color(0xFF8B5CF6), // Purple color
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyTeamScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeModuleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
