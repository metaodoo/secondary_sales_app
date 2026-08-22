import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/app/navigation/app_shell.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/dashboard/dashboard_summary.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/dashboard/dashboard_provider.dart';
import 'package:secondary_sales/features/hr/attendance_provider.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';
import 'package:secondary_sales/features/hr/screens/expense_dashboard_screen.dart';
import 'package:secondary_sales/features/hr/screens/leave_dashboard_screen.dart';
import 'package:secondary_sales/features/my_team/screens/my_team_screen.dart';
import 'package:secondary_sales/features/notifications/notification_provider.dart';
import 'package:secondary_sales/features/notifications/widgets/notification_bell.dart';
import 'package:secondary_sales/features/settings/screens/settings_tab.dart';
import 'package:secondary_sales/features/dashboard/module_launcher.dart';

/// Post-login landing dashboard.
///
/// The summary section is now range-based and driven by the richer
/// `/dashboard/summary` payload, while the existing module launcher remains the
/// primary way to enter the rest of the app.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _modulesSectionKey = GlobalKey();

  String _preset = 'today';
  DateTime? _customDateFrom;
  DateTime? _customDateTo;
  bool _showTeam = true;
  bool _showModuleShortcut = true;
  bool _moduleVisibilityCheckScheduled = false;

  /// Action-only attendance provider: reused purely for the hero's one-tap
  /// check-in/out (GPS + geofence live in [AttendanceProvider.performAction]).
  /// The hero's displayed state comes from the dashboard summary, so this never
  /// needs its own status/history load — hence `autoLoad: false`.
  late final AttendanceProvider _attendance;

  @override
  void initState() {
    super.initState();
    _attendance = AttendanceProvider(
      context.read<AuthProvider>(),
      autoLoad: false,
    );
    _scrollController.addListener(_updateModuleShortcutVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleModuleVisibilityCheck();
      _fetchDashboard();
      context.read<NotificationProvider>().refreshUnreadCount();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateModuleShortcutVisibility)
      ..dispose();
    _attendance.dispose();
    super.dispose();
  }

  /// One-tap check-in / check-out from the dashboard hero. Reuses the existing
  /// geofenced action, then refreshes the summary so the hero reflects the new
  /// state. Surfaces geofence / permission failures as a snackbar.
  Future<void> _toggleAttendance(bool currentlyCheckedIn) async {
    final ok = await _attendance.performAction(
      currentlyCheckedIn ? 'check_out' : 'check_in',
    );
    if (!mounted) return;
    if (ok) {
      await _fetchDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _attendance.errorMessage ?? 'Could not update attendance.',
          ),
        ),
      );
    }
  }

  Future<void> _fetchDashboard() {
    return context
        .read<DashboardProvider>()
        .fetch(
          preset: _preset,
          dateFrom: _preset == 'custom' ? _customDateFrom : null,
          dateTo: _preset == 'custom' ? _customDateTo : null,
        )
        .whenComplete(_scheduleModuleVisibilityCheck);
  }

  Future<void> _refresh() => _fetchDashboard();

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _scheduleModuleVisibilityCheck() {
    if (_moduleVisibilityCheckScheduled) return;
    _moduleVisibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moduleVisibilityCheckScheduled = false;
      _updateModuleShortcutVisibility();
    });
  }

  void _updateModuleShortcutVisibility() {
    if (!mounted) return;
    final sectionContext = _modulesSectionKey.currentContext;
    final renderObject = sectionContext?.findRenderObject();

    var shouldShow = true;
    if (renderObject is RenderBox && renderObject.hasSize) {
      final sectionTop = renderObject.localToGlobal(Offset.zero).dy;
      final screenHeight = MediaQuery.sizeOf(context).height;
      shouldShow = sectionTop > screenHeight;
    }

    if (_showModuleShortcut != shouldShow) {
      setState(() => _showModuleShortcut = shouldShow);
    }
  }

  Future<void> _showModulePicker(List<_ModuleItem> items) {
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
                              if (mounted) items[i].onTap();
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

  Future<void> _selectPreset(String preset) async {
    if (preset == 'custom') {
      await _pickCustomRange();
      return;
    }
    setState(() {
      _preset = preset;
      _customDateFrom = null;
      _customDateTo = null;
    });
    await _fetchDashboard();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateFrom != null && _customDateTo != null
          ? DateTimeRange(start: _customDateFrom!, end: _customDateTo!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryStrong,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _preset = 'custom';
      _customDateFrom = picked.start;
      _customDateTo = picked.end;
    });
    await _fetchDashboard();
  }

  String _activeRangeCaption(DashboardSummary? summary) {
    if (summary?.dateFrom != null && summary?.dateTo != null) {
      final from = DateFormat('MMM d').format(summary!.dateFrom!);
      final to = DateFormat('MMM d').format(summary.dateTo!);
      if (from == to) return from;
      return '$from - $to';
    }
    switch (_preset) {
      case 'week':
        return 'This week';
      case 'month':
        return 'This month';
      case 'custom':
        if (_customDateFrom != null && _customDateTo != null) {
          final from = DateFormat('MMM d').format(_customDateFrom!);
          final to = DateFormat('MMM d').format(_customDateTo!);
          return '$from - $to';
        }
        return 'Custom range';
      default:
        return 'Today';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final summary = dash.summary;

    final user = auth.user;
    final userName = user?.employeeName ?? user?.name;
    final firstName = firstNameFromName(userName);

    final canAccessPrimary = auth.canAccessPrimarySales;
    final canAccessSecondary = auth.canAccessSecondarySales;
    final canAccessAttendance = auth.canView(AppScreen.moduleAttendance);
    final canAccessLeave = auth.canView(AppScreen.moduleLeave);
    final canAccessExpense = auth.canView(AppScreen.moduleExpense);
    final canAccessMyTeam = auth.canView(AppScreen.moduleMyTeam);

    final canShowTeam = summary?.hasTeam ?? false;
    final showTeam = canShowTeam && _showTeam;
    final attendance = summary?.attendance;
    final reportMembers =
        summary?.reportMembers ?? const <TeamMemberProgress>[];
    final headlineTarget = summary?.headlineTarget;
    final primaryScope = summary?.orders?.primary;
    final primaryOrders = _selectOrderMetric(primaryScope, showTeam);
    final primaryIsTeam = _selectedOrderMetricIsTeam(primaryScope, showTeam);
    final secondaryScope = summary?.orders?.secondary;
    final secondaryOrders = _selectOrderMetric(secondaryScope, showTeam);
    final secondaryIsTeam = _selectedOrderMetricIsTeam(
      secondaryScope,
      showTeam,
    );
    final visitsScope = summary?.visits;
    final visits = _selectVisitMetric(visitsScope, showTeam);
    final visitsIsTeam = _selectedVisitMetricIsTeam(visitsScope, showTeam);
    final moduleItems = <_ModuleItem>[
      if (canAccessPrimary)
        _ModuleItem(
          title: 'Primary',
          icon: Icons.factory_outlined,
          color: AppColors.primaryStrong,
          onTap: () => _open(const AppShell(moduleType: 'primary')),
        ),
      if (canAccessSecondary)
        _ModuleItem(
          title: 'Secondary',
          icon: Icons.storefront_outlined,
          color: const Color(0xFF10B981),
          onTap: () => _open(const AppShell(moduleType: 'secondary')),
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
    ];

    _scheduleModuleVisibilityCheck();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
          const NotificationBell(),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileAvatar(
              onTap: () =>
                  _open(SettingsTab(onBack: () => Navigator.of(context).pop())),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              moduleItems.isEmpty ? 32 : 112,
            ),
            children: [
              Text(
                'Welcome back,',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              Text(
                userName ?? 'User',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _activeRangeCaption(summary),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              if (canAccessAttendance) ...[
                ListenableBuilder(
                  listenable: _attendance,
                  builder: (context, _) => _AttendanceHero(
                    summary: summary,
                    busy: _attendance.isActionLoading,
                    loadingMessage: _attendance.loadingMessage,
                    onToggle: () =>
                        _toggleAttendance(summary?.isCheckedIn ?? false),
                    onOpen: () => _open(const AttendanceScreen()),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const SectionHeader(title: 'Summary'),
              const SizedBox(height: 12),
              _RangeSelector(preset: _preset, onSelect: _selectPreset),
              const SizedBox(height: 12),

              if (canShowTeam) ...[
                _ScopeToggle(
                  showTeam: showTeam,
                  onChanged: (value) => setState(() => _showTeam = value),
                ),
                const SizedBox(height: 16),
              ],

              if (attendance != null) ...[
                _AttendanceSummaryCard(
                  attendance: attendance,
                  showTeam: showTeam,
                ),
                const SizedBox(height: 16),
              ],

              if (headlineTarget != null &&
                  (headlineTarget.targetQty > 0 ||
                      headlineTarget.achievedQty > 0)) ...[
                _AchievementCard(
                  target: headlineTarget,
                  label: summary?.isManager == true
                      ? 'Team sales · achievement'
                      : 'My sales · achievement',
                ),
                const SizedBox(height: 16),
              ],

              if (showTeam && reportMembers.isNotEmpty) ...[
                _TeamBreakdownCard(
                  members: reportMembers,
                  onViewAll: canAccessMyTeam
                      ? () => _open(const MyTeamScreen())
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              if (primaryOrders != null) ...[
                _OrdersCard(
                  title: 'Orders · Primary',
                  metric: primaryOrders,
                  accentColor: AppColors.primaryStrong,
                  icon: Icons.factory_outlined,
                  scopeLabel: primaryIsTeam ? 'team total' : 'you',
                  currency: summary?.currency,
                ),
                const SizedBox(height: 16),
              ],

              if (secondaryOrders != null) ...[
                _OrdersCard(
                  title: 'Orders · Secondary',
                  metric: secondaryOrders,
                  accentColor: const Color(0xFF0D9488),
                  icon: Icons.shopping_bag_outlined,
                  scopeLabel: secondaryIsTeam ? 'team total' : 'you',
                  currency: summary?.currency,
                ),
                const SizedBox(height: 16),
              ],

              if (visits != null) ...[
                _VisitsCard(
                  metric: visits,
                  title: visitsIsTeam
                      ? 'Outlet visits · team total'
                      : 'Outlet visits',
                ),
                const SizedBox(height: 16),
              ],

              if ((summary?.approvals?.total ?? 0) > 0) ...[
                _ApprovalsCard(approvals: summary!.approvals!),
                const SizedBox(height: 16),
              ],

              if (moduleItems.isNotEmpty) ...[
                Container(
                  key: _modulesSectionKey,
                  child: const SectionHeader(title: 'Modules'),
                ),
                const SizedBox(height: 12),
                _ModulesGrid(items: moduleItems),
              ],
            ],
          ),
        ),
      ),
    ),
    if (moduleItems.isNotEmpty)
      ModuleLauncherFab(visible: _showModuleShortcut),
  ],
);
  }
}

class _AttendanceHero extends StatelessWidget {
  const _AttendanceHero({
    required this.summary,
    required this.busy,
    this.loadingMessage = '',
    required this.onToggle,
    required this.onOpen,
  });

  final DashboardSummary? summary;

  /// True while a check-in/out network action is in flight (shows a spinner).
  final bool busy;

  /// Detailed loading status message.
  final String loadingMessage;

  /// One-tap check-in / check-out (the button).
  final VoidCallback onToggle;

  /// Opens the full Attendance screen (tapping the card body).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final checkedIn = summary?.isCheckedIn ?? false;
    final known = summary != null;

    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String subtitle;

    if (busy && loadingMessage.isNotEmpty) {
      bg = AppColors.primarySoft;
      fg = AppColors.primary;
      icon = Icons.camera_alt;
      title = 'Attendance';
      subtitle = loadingMessage;
    } else if (checkedIn) {
      bg = AppColors.successSoft;
      fg = const Color(0xFF166534);
      icon = Icons.check_circle;
      title = 'Logged in';
      subtitle = summary?.checkInTime != null
          ? 'Since ${summary!.checkInTime} · tap for history'
          : 'On shift · tap for history';
    } else {
      bg = AppColors.warningSoft;
      fg = const Color(0xFF92400E);
      icon = Icons.schedule;
      title = known ? "Logged out" : 'Attendance';
      subtitle = known
          ? 'One tap · selfie & location'
          : 'Log in / out and view history';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onOpen,
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
              const SizedBox(width: 8),
              _CheckButton(
                checkedIn: checkedIn,
                busy: busy,
                fg: fg,
                onTap: busy ? null : onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

AttendanceWindow _selectAttendanceWindow(
  DashboardAttendanceSummary attendance,
  bool showTeam,
) {
  if (!showTeam || attendance.team == null) return attendance.my;
  return AttendanceWindow(
    present: attendance.my.present + attendance.team!.present,
    absent: attendance.my.absent + attendance.team!.absent,
    late: attendance.my.late + attendance.team!.late,
  );
}

DashboardOrderMetric? _selectOrderMetric(
  DashboardOrderScope? scope,
  bool showTeam,
) {
  if (scope == null) return null;
  if (!showTeam) return scope.my;
  return _sumOrderMetrics(scope.my, scope.team) ?? scope.team ?? scope.my;
}

bool _selectedOrderMetricIsTeam(DashboardOrderScope? scope, bool showTeam) {
  if (scope == null) return false;
  if (showTeam) return scope.team != null || scope.my != null;
  return false;
}

DashboardOrderMetric? _sumOrderMetrics(
  DashboardOrderMetric? my,
  DashboardOrderMetric? team,
) {
  if (my == null && team == null) return null;
  return DashboardOrderMetric(
    count: (my?.count ?? 0) + (team?.count ?? 0),
    value: (my?.value ?? 0) + (team?.value ?? 0),
  );
}

DashboardVisitMetric? _selectVisitMetric(
  DashboardVisitsSummary? scope,
  bool showTeam,
) {
  if (scope == null) return null;
  if (!showTeam) return scope.my;
  return _sumVisitMetrics(scope.my, scope.team) ?? scope.team ?? scope.my;
}

bool _selectedVisitMetricIsTeam(DashboardVisitsSummary? scope, bool showTeam) {
  if (scope == null) return false;
  if (showTeam) return scope.team != null || scope.my != null;
  return false;
}

DashboardVisitMetric? _sumVisitMetrics(
  DashboardVisitMetric? my,
  DashboardVisitMetric? team,
) {
  if (my == null && team == null) return null;
  return DashboardVisitMetric(
    total: (my?.total ?? 0) + (team?.total ?? 0),
    withOrder: (my?.withOrder ?? 0) + (team?.withOrder ?? 0),
    noOrder: (my?.noOrder ?? 0) + (team?.noOrder ?? 0),
  );
}

/// The inline check-in / check-out button inside the attendance hero. Nested in
/// its own [InkWell] so its tap does not bubble to the hero's "open history" tap.
class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.checkedIn,
    required this.busy,
    required this.fg,
    required this.onTap,
  });

  final bool checkedIn;
  final bool busy;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final filled = !checkedIn;
    final bg = filled ? AppColors.primaryStrong : Colors.white;
    final border = filled ? AppColors.primaryStrong : fg.withValues(alpha: 0.4);
    final labelColor = filled ? Colors.white : fg;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.small),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(color: border),
          ),
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(labelColor),
                  ),
                )
              : Text(
                  checkedIn ? 'Log Out' : 'Log In',
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.preset, required this.onSelect});

  final String preset;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _RangeChip(
          label: 'Today',
          selected: preset == 'today',
          onTap: () => onSelect('today'),
        ),
        _RangeChip(
          label: 'Week',
          selected: preset == 'week',
          onTap: () => onSelect('week'),
        ),
        _RangeChip(
          label: 'Month',
          selected: preset == 'month',
          onTap: () => onSelect('month'),
        ),
        _RangeChip(
          label: 'Custom',
          selected: preset == 'custom',
          icon: Icons.date_range_outlined,
          onTap: () => onSelect('custom'),
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryStrong : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primaryStrong : AppColors.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({required this.showTeam, required this.onChanged});

  final bool showTeam;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeButton(
              label: 'My',
              selected: !showTeam,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ScopeButton(
              label: 'My Team',
              selected: showTeam,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeButton extends StatelessWidget {
  const _ScopeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryStrong : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primaryStrong,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  const _AttendanceSummaryCard({
    required this.attendance,
    required this.showTeam,
  });

  final DashboardAttendanceSummary attendance;
  final bool showTeam;

  @override
  Widget build(BuildContext context) {
    final selectedWindow = _selectAttendanceWindow(attendance, showTeam);
    final selectedLabel = showTeam && attendance.team != null
        ? 'Team total'
        : 'You';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          _AttendanceRow(label: selectedLabel, window: selectedWindow),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.label, required this.window});

  final String label;
  final AttendanceWindow window;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _AttendanceStat(
                label: 'Present',
                value: window.present.toString(),
                bg: AppColors.successSoft,
                fg: const Color(0xFF166534),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttendanceStat(
                label: 'Absent',
                value: window.absent.toString(),
                bg: const Color(0xFFFEE2E2),
                fg: const Color(0xFFB91C1C),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttendanceStat(
                label: 'Late',
                value: window.late.toString(),
                bg: const Color(0xFFFEF3C7),
                fg: const Color(0xFFB45309),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });

  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.target, required this.label});

  final TargetProgress target;
  final String label;

  @override
  Widget build(BuildContext context) {
    final percent = target.percent.round();
    final color = percent >= 85
        ? const Color(0xFF16A34A)
        : percent >= 70
        ? const Color(0xFFD97706)
        : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                ),
              ),
              const Spacer(),
              Text(
                '${_fmtQty(target.achievedQty)} / ${_fmtQty(target.targetQty)} units',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(fraction: target.fraction, color: color),
        ],
      ),
    );
  }
}

class _TeamBreakdownCard extends StatelessWidget {
  const _TeamBreakdownCard({required this.members, this.onViewAll});

  final List<TeamMemberProgress> members;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'By report · sales vs target',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      color: AppColors.primaryStrong,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final member in shown) _TeamMemberRow(member: member),
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
    final color = member.percent >= 85
        ? const Color(0xFF16A34A)
        : member.percent >= 70
        ? const Color(0xFFD97706)
        : const Color(0xFFDC2626);

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
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TeamMetricChip(
                      label: 'Achieved',
                      value: _fmtQty(member.achievedQty),
                      bg: AppColors.successSoft,
                      fg: const Color(0xFF166534),
                    ),
                    _TeamMetricChip(
                      label: 'Target',
                      value: _fmtQty(member.targetQty),
                      bg: AppColors.primarySoft,
                      fg: AppColors.primaryStrong,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: _ProgressBar(fraction: member.fraction, color: color),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              '${member.percent.round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMetricChip extends StatelessWidget {
  const _TeamMetricChip({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });

  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

class _OrdersCard extends StatelessWidget {
  const _OrdersCard({
    required this.title,
    required this.metric,
    required this.accentColor,
    required this.icon,
    required this.scopeLabel,
    this.currency,
  });

  final String title;
  final DashboardOrderMetric metric;
  final Color accentColor;
  final IconData icon;
  final String scopeLabel;
  final DashboardCurrency? currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ssPanelDecoration(),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtMoney(metric.value, currency),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$scopeLabel · ${metric.count} orders',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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

class _VisitsCard extends StatelessWidget {
  const _VisitsCard({required this.metric, required this.title});

  final DashboardVisitMetric metric;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ssPanelDecoration(),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    metric.total.toString(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${metric.productivePercent}% productive',
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: metric.productiveFraction,
                  backgroundColor: AppColors.borderMuted,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF16A34A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _LegendDot(
                    color: const Color(0xFF16A34A),
                    text: 'With order ${metric.withOrder}',
                  ),
                  const SizedBox(width: 16),
                  _LegendDot(
                    color: AppColors.textSecondary,
                    text: 'No order ${metric.noOrder}',
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
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
          const Icon(
            Icons.assignment_turned_in_outlined,
            color: AppColors.primaryStrong,
          ),
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: AppColors.borderMuted,
        valueColor: AlwaysStoppedAnimation<Color>(color),
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
    if (items.isEmpty) return const SizedBox.shrink();
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

class _ModulePickerTile extends StatelessWidget {
  const _ModulePickerTile({required this.item, required this.onTap});

  final _ModuleItem item;
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

String _fmtQty(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

/// Formats a money value compactly using the reporting currency from Odoo
/// (symbol + before/after position). Falls back to a bare number when the
/// backend didn't send a currency.
String _fmtMoney(double value, DashboardCurrency? currency) {
  final number = NumberFormat.compact().format(value);
  if (currency == null) return number;
  return currency.symbolBefore
      ? '${currency.symbol}$number'
      : '$number ${currency.symbol}';
}
