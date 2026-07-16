import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/app/navigation/app_shell.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/dashboard/dashboard_summary.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/dashboard/dashboard_provider.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/expense_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/my_team/screens/my_team_screen.dart';
import 'package:secondary_sales/features/settings/screens/settings_tab.dart';

/// Post-login landing. Replaces the bare 5-card module picker with a role-aware
/// dashboard: an attendance hero, a target-achievement KPI, a Sales Officer's
/// today-route (or a Manager's team roll-up + approvals), and the gated module
/// grid for navigation. KPI sections render only when `/dashboard/summary` has
/// data — otherwise the screen still works from attendance + modules alone.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().fetch();
    });
  }

  Future<void> _refresh() => context.read<DashboardProvider>().fetch();

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final summary = dash.summary;

    final user = auth.user;
    final userName = user?.employeeName ?? user?.name ?? 'User';
    final firstName = userName.trim().split(' ').first;

    final canAccessPrimary = auth.canAccessPrimarySales;
    final canAccessSecondary = auth.canAccessSecondarySales;
    final canAccessAttendance = auth.canView(AppScreen.moduleAttendance);
    final canAccessLeave = auth.canView(AppScreen.moduleLeave);
    final canAccessExpense = auth.canView(AppScreen.moduleExpense);
    final canAccessMyTeam = auth.canView(AppScreen.moduleMyTeam);

    final isManager = summary?.isManager ?? canAccessMyTeam;

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
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileAvatar(
              onTap: () => _open(
                SettingsTab(onBack: () => Navigator.of(context).pop()),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'Welcome back,',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              Text(
                firstName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 20),

              if (canAccessAttendance) ...[
                _AttendanceHero(
                  summary: summary,
                  onTap: () => _open(const AttendanceScreen()),
                ),
                const SizedBox(height: 20),
              ],

              if (summary?.target != null) ...[
                _TargetCard(target: summary!.target!, isTeam: isManager),
                const SizedBox(height: 20),
              ],

              if (isManager) ...[
                if (summary?.team != null) ...[
                  _TeamSection(
                    team: summary!.team!,
                    onViewAll: () => _open(const MyTeamScreen()),
                  ),
                  const SizedBox(height: 20),
                ],
                if ((summary?.approvals?.total ?? 0) > 0) ...[
                  _ApprovalsCard(approvals: summary!.approvals!),
                  const SizedBox(height: 20),
                ],
              ] else ...[
                if (summary?.route != null) ...[
                  _RouteCard(route: summary!.route!),
                  const SizedBox(height: 20),
                ],
              ],

              const SectionHeader(title: 'Modules'),
              const SizedBox(height: 12),
              _ModulesGrid(
                items: [
                  if (canAccessPrimary)
                    _ModuleItem(
                      title: 'Primary',
                      icon: Icons.factory_outlined,
                      color: AppColors.primaryStrong,
                      onTap: () =>
                          _open(const AppShell(moduleType: 'primary')),
                    ),
                  if (canAccessSecondary)
                    _ModuleItem(
                      title: 'Secondary',
                      icon: Icons.storefront_outlined,
                      color: const Color(0xFF10B981),
                      onTap: () =>
                          _open(const AppShell(moduleType: 'secondary')),
                    ),
                  if (canAccessAttendance)
                    _ModuleItem(
                      title: 'Attendance',
                      icon: Icons.access_time_filled_outlined,
                      color: const Color(0xFFF59E0B),
                      onTap: () => _open(const AttendanceScreen()),
                    ),
                  if (canAccessLeave)
                    _ModuleItem(
                      title: 'Leave Request',
                      icon: Icons.event_busy_outlined,
                      color: const Color(0xFFEF4444),
                      onTap: () => _open(const LeaveDashboardScreen()),
                    ),
                  if (canAccessExpense)
                    _ModuleItem(
                      title: 'Expense',
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFF6366F1),
                      onTap: () => _open(const ExpenseDashboardScreen()),
                    ),
                  if (canAccessMyTeam)
                    _ModuleItem(
                      title: 'My Team',
                      icon: Icons.group_outlined,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _open(const MyTeamScreen()),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance hero
// ---------------------------------------------------------------------------

class _AttendanceHero extends StatelessWidget {
  const _AttendanceHero({required this.summary, required this.onTap});

  final DashboardSummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checkedIn = summary?.isCheckedIn ?? false;
    final known = summary != null;

    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String subtitle;

    if (checkedIn) {
      bg = AppColors.successSoft;
      fg = const Color(0xFF166534);
      icon = Icons.check_circle;
      title = 'Checked in';
      subtitle = summary?.checkInTime != null
          ? 'Since ${summary!.checkInTime}'
          : 'You are on shift';
    } else {
      bg = AppColors.warningSoft;
      fg = const Color(0xFF92400E);
      icon = Icons.schedule;
      title = known ? "You're not checked in" : 'Attendance';
      subtitle = known ? 'Tap to check in' : 'Check in / out and view history';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!checkedIn)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryStrong,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: const Text(
                    'Check In',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target achievement (Σ delivered ÷ Σ target)
// ---------------------------------------------------------------------------

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target, required this.isTeam});

  final TargetProgress target;
  final bool isTeam;

  @override
  Widget build(BuildContext context) {
    final unit = target.unitLabel ?? 'units';
    final percent = target.percent.round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTeam ? 'Team target · This month' : 'My target · This month',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressBar(fraction: target.fraction),
          const SizedBox(height: 10),
          Text(
            '${_fmtQty(target.achievedQty)} / ${_fmtQty(target.targetQty)} $unit delivered',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sales Officer — today's route
// ---------------------------------------------------------------------------

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final RouteProgress route;

  @override
  Widget build(BuildContext context) {
    final left = (route.planned - route.visited).clamp(0, route.planned);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's route",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _RouteStat(value: '${route.visited}/${route.planned}', label: 'Visited'),
              _RouteStat(value: '${route.productive}', label: 'Productive'),
              _RouteStat(value: '$left', label: 'Remaining'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryStrong,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manager — team roll-up
// ---------------------------------------------------------------------------

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.team, required this.onViewAll});

  final TeamSummary team;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final shown = team.members.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My team · ${team.present}/${team.total} checked in',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in shown) _TeamMemberRow(member: m),
        ],
      ),
    );
  }
}

class _TeamMemberRow extends StatelessWidget {
  const _TeamMemberRow({required this.member});

  final TeamMemberProgress member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: member.isCheckedIn
                ? const Color(0xFF22C55E)
                : AppColors.borderSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              member.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: _ProgressBar(fraction: member.fraction),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '${member.percent.round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalsCard extends StatelessWidget {
  const _ApprovalsCard({required this.approvals});

  final ApprovalsSummary approvals;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (approvals.leave > 0) '${approvals.leave} leave',
      if (approvals.expense > 0) '${approvals.expense} expense',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in_outlined,
              color: AppColors.primaryStrong),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pending approvals · ${parts.join(' · ')}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: AppColors.borderMuted,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
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

class _ModulesGrid extends StatelessWidget {
  const _ModulesGrid({required this.items});

  final List<_ModuleItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: items
          .map(
            (item) => Container(
              decoration: ssPanelDecoration(),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, color: item.color, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Trims a trailing `.0` so whole quantities render as `1240` not `1240.0`.
String _fmtQty(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
