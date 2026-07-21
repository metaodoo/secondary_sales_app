import 'package:secondary_sales/core/util/parse.dart';

/// Role-aware landing-dashboard snapshot returned by `/dashboard/summary`.
///
/// The payload is in transition from the original compact dashboard contract to
/// a richer date-range summary. This model parses both shapes so the app can
/// move incrementally without hard-failing on either backend version.
class DashboardSummary {
  const DashboardSummary({
    this.role = '',
    this.hasTeam = false,
    this.isCheckedIn = false,
    this.isScoped = false,
    this.checkInTime,
    this.scopeEmployeeId,
    this.scopeEmployeeName,
    this.preset,
    this.dateFrom,
    this.dateTo,
    this.attendance,
    this.achievement,
    this.orders,
    this.visits,
    this.currency,
    this.target,
    this.route,
    this.team,
    this.approvals,
  });

  final String role;
  final bool hasTeam;
  final bool isCheckedIn;
  final bool isScoped;
  final String? checkInTime;
  final int? scopeEmployeeId;
  final String? scopeEmployeeName;
  final String? preset;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  final DashboardAttendanceSummary? attendance;
  final DashboardAchievementSummary? achievement;
  final DashboardOrdersSummary? orders;
  final DashboardVisitsSummary? visits;

  /// Reporting currency (company currency) for the money figures.
  final DashboardCurrency? currency;

  /// Legacy aliases kept while the UI migrates.
  final TargetProgress? target;
  final RouteProgress? route;
  final TeamSummary? team;
  final ApprovalsSummary? approvals;

  bool get isManager => role == 'manager' || hasTeam || team != null;
  TargetProgress? get headlineTarget => achievement?.my ?? target;
  List<TeamMemberProgress> get reportMembers {
    final reports = achievement?.reports ?? const <TeamMemberProgress>[];
    return reports.isNotEmpty
        ? reports
        : (team?.members ?? const <TeamMemberProgress>[]);
  }

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    final attendance = DashboardAttendanceSummary.fromMapOrNull(
      asMapOrNull(map['attendance']),
    );
    final achievement = DashboardAchievementSummary.fromMapOrNull(
      asMapOrNull(map['achievement']),
    );
    final legacyTarget = TargetProgress.fromMapOrNull(
      asMapOrNull(map['target']),
    );
    final derivedTeam = TeamSummary.fromBlocks(attendance, achievement);

    return DashboardSummary(
      role: (map['role'] ?? '').toString().trim().toLowerCase(),
      hasTeam:
          asBool(map['has_team']) ||
          asMapOrNull(map['team']) != null ||
          (achievement?.reports.isNotEmpty ?? false),
      isCheckedIn: asBool(map['is_checked_in']),
      isScoped: asBool(map['is_scoped']),
      checkInTime: asNullableString(map['check_in_time']),
      scopeEmployeeId: asIntOrNull(map['scope_employee_id']),
      scopeEmployeeName: asNullableString(map['scope_employee_name']),
      preset: asNullableString(map['preset']),
      dateFrom: asDateTime(map['date_from']),
      dateTo: asDateTime(map['date_to']),
      attendance: attendance,
      achievement: achievement,
      orders: DashboardOrdersSummary.fromMapOrNull(asMapOrNull(map['orders'])),
      visits: DashboardVisitsSummary.fromMapOrNull(asMapOrNull(map['visits'])),
      currency: DashboardCurrency.fromMapOrNull(asMapOrNull(map['currency'])),
      target: legacyTarget ?? achievement?.my,
      route: RouteProgress.fromMapOrNull(
        asMapOrNull(map['today_route'] ?? map['route']),
      ),
      team: TeamSummary.fromMapOrNull(asMapOrNull(map['team'])) ?? derivedTeam,
      approvals: ApprovalsSummary.fromMapOrNull(asMapOrNull(map['approvals'])),
    );
  }
}

class DashboardAttendanceSummary {
  const DashboardAttendanceSummary({required this.my, this.team});

  final AttendanceWindow my;
  final AttendanceWindow? team;

  static DashboardAttendanceSummary? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    final my = AttendanceWindow.fromMapOrNull(asMapOrNull(map['my']));
    if (my == null) return null;
    return DashboardAttendanceSummary(
      my: my,
      team: AttendanceWindow.fromMapOrNull(asMapOrNull(map['team'])),
    );
  }
}

class AttendanceWindow {
  const AttendanceWindow({required this.present, required this.absent});

  final int present;
  final int absent;

  int get total => present + absent;

  static AttendanceWindow? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return AttendanceWindow(
      present: asInt(map['present']),
      absent: asInt(map['absent']),
    );
  }
}

class DashboardAchievementSummary {
  const DashboardAchievementSummary({this.my, required this.reports});

  final TargetProgress? my;
  final List<TeamMemberProgress> reports;

  static DashboardAchievementSummary? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    final rawReports = map['reports'];
    final reports = rawReports is List
        ? rawReports
              .map((e) => TeamMemberProgress.fromMap(asMap(e)))
              .toList(growable: false)
        : const <TeamMemberProgress>[];
    return DashboardAchievementSummary(
      my: TargetProgress.fromMapOrNull(asMapOrNull(map['my'])),
      reports: reports,
    );
  }
}

class DashboardOrdersSummary {
  const DashboardOrdersSummary({
    required this.primary,
    required this.secondary,
  });

  final DashboardOrderScope primary;
  final DashboardOrderScope secondary;

  static DashboardOrdersSummary? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return DashboardOrdersSummary(
      primary: DashboardOrderScope.fromMap(asMap(map['primary'])),
      secondary: DashboardOrderScope.fromMap(asMap(map['secondary'])),
    );
  }
}

class DashboardOrderScope {
  const DashboardOrderScope({this.my, this.team});

  final DashboardOrderMetric? my;
  final DashboardOrderMetric? team;

  bool get hasData => my != null || team != null;

  static DashboardOrderScope fromMap(Map<String, dynamic> map) {
    return DashboardOrderScope(
      my: DashboardOrderMetric.fromMapOrNull(asMapOrNull(map['my'])),
      team: DashboardOrderMetric.fromMapOrNull(asMapOrNull(map['team'])),
    );
  }
}

class DashboardOrderMetric {
  const DashboardOrderMetric({required this.count, required this.value});

  final int count;
  final double value;

  static DashboardOrderMetric? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return DashboardOrderMetric(
      count: asInt(map['count']),
      value: asDouble(map['value']),
    );
  }
}

class DashboardVisitsSummary {
  const DashboardVisitsSummary({this.my, this.team});

  final DashboardVisitMetric? my;
  final DashboardVisitMetric? team;

  static DashboardVisitsSummary? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return DashboardVisitsSummary(
      my: DashboardVisitMetric.fromMapOrNull(asMapOrNull(map['my'])),
      team: DashboardVisitMetric.fromMapOrNull(asMapOrNull(map['team'])),
    );
  }
}

class DashboardVisitMetric {
  const DashboardVisitMetric({
    required this.total,
    required this.withOrder,
    required this.noOrder,
  });

  final int total;
  final int withOrder;
  final int noOrder;

  double get productiveFraction => total <= 0 ? 0 : withOrder / total;
  int get productivePercent => (productiveFraction * 100).round();

  static DashboardVisitMetric? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return DashboardVisitMetric(
      total: asInt(map['total']),
      withOrder: asInt(map['with_order']),
      noOrder: asInt(map['no_order']),
    );
  }
}

/// Reporting currency from Odoo (`res.currency`): symbol, ISO code, and whether
/// the symbol sits before or after the amount.
class DashboardCurrency {
  const DashboardCurrency({
    required this.symbol,
    required this.code,
    required this.position,
  });

  final String symbol;
  final String code;

  /// 'before' | 'after' — where the symbol sits relative to the amount.
  final String position;

  bool get symbolBefore => position != 'after';

  static DashboardCurrency? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    final symbol = asNullableString(map['symbol']) ?? '';
    final code = asNullableString(map['code']) ?? '';
    if (symbol.isEmpty && code.isEmpty) return null;
    return DashboardCurrency(
      symbol: symbol.isNotEmpty ? symbol : code,
      code: code,
      position: asNullableString(map['position']) ?? 'after',
    );
  }
}

/// Overall-units achievement: Σ delivered qty ÷ Σ target qty (the agreed
/// headline rollup over per-SKU `sale.target.line` records).
class TargetProgress {
  const TargetProgress({
    required this.achievedQty,
    required this.targetQty,
    this.unitLabel,
  });

  final double achievedQty;
  final double targetQty;

  /// Optional unit hint (e.g. 'units', 'cases'); null when SKUs mix UOMs.
  final String? unitLabel;

  double get percent => targetQty <= 0 ? 0 : (achievedQty / targetQty * 100);
  double get fraction =>
      targetQty <= 0 ? 0 : (achievedQty / targetQty).clamp(0.0, 1.0);

  static TargetProgress? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return TargetProgress(
      achievedQty: asDouble(map['achieved_qty'] ?? map['delivered_qty']),
      targetQty: asDouble(map['target_qty']),
      unitLabel: asNullableString(map['unit_label']),
    );
  }
}

/// Planned = today's `route.planner.line` outlets for the weekday;
/// visited = today's `outlet.visit` check-ins; productive = visits with an order.
class RouteProgress {
  const RouteProgress({
    required this.visited,
    required this.planned,
    required this.productive,
  });

  final int visited;
  final int planned;
  final int productive;

  static RouteProgress? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return RouteProgress(
      visited: asInt(map['visited']),
      planned: asInt(map['planned']),
      productive: asInt(map['productive']),
    );
  }
}

class TeamSummary {
  const TeamSummary({
    required this.present,
    required this.total,
    required this.members,
  });

  final int present;
  final int total;
  final List<TeamMemberProgress> members;

  static TeamSummary? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    final rawMembers = map['members'];
    final members = rawMembers is List
        ? rawMembers
              .map((e) => TeamMemberProgress.fromMap(asMap(e)))
              .toList(growable: false)
        : const <TeamMemberProgress>[];
    return TeamSummary(
      present: asInt(map['present']),
      total: asInt(map['total']),
      members: members,
    );
  }

  static TeamSummary? fromBlocks(
    DashboardAttendanceSummary? attendance,
    DashboardAchievementSummary? achievement,
  ) {
    final teamAttendance = attendance?.team;
    final reports = achievement?.reports ?? const <TeamMemberProgress>[];
    if (teamAttendance == null && reports.isEmpty) return null;
    return TeamSummary(
      present: teamAttendance?.present ?? 0,
      total: teamAttendance?.total ?? reports.length,
      members: reports,
    );
  }
}

class TeamMemberProgress {
  const TeamMemberProgress({
    required this.id,
    required this.name,
    required this.percent,
    required this.isCheckedIn,
    this.achievedQty = 0,
    this.targetQty = 0,
    this.subCount = 0,
  });

  final int id;
  final String name;
  final double percent;
  final bool isCheckedIn;
  final double achievedQty;
  final double targetQty;
  final int subCount;

  double get fraction => (percent / 100).clamp(0.0, 1.0);

  factory TeamMemberProgress.fromMap(Map<String, dynamic> map) {
    return TeamMemberProgress(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      percent: asDouble(map['percent']),
      isCheckedIn: asBool(map['is_checked_in']),
      achievedQty: asDouble(map['achieved_qty']),
      targetQty: asDouble(map['target_qty']),
      subCount: asInt(map['sub_count']),
    );
  }
}

class ApprovalsSummary {
  const ApprovalsSummary({required this.leave, required this.expense});

  final int leave;
  final int expense;

  int get total => leave + expense;

  static ApprovalsSummary? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    return ApprovalsSummary(
      leave: asInt(map['leave']),
      expense: asInt(map['expense']),
    );
  }
}
