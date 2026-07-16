import 'package:secondary_sales/core/util/parse.dart';

/// Role-aware landing-dashboard snapshot returned by `/dashboard/summary`.
///
/// Every section is nullable so the UI can render progressively: until the
/// backend endpoint ships (or when it is unreachable), the provider holds a
/// null summary and the dashboard falls back to attendance + module navigation
/// only — no section is required for the screen to function.
class DashboardSummary {
  const DashboardSummary({
    this.role = '',
    this.isCheckedIn = false,
    this.checkInTime,
    this.target,
    this.route,
    this.team,
    this.approvals,
  });

  /// Server-declared role: 'so' | 'manager' | '' (unknown). The UI also infers
  /// manager from the presence of a [team] block as a fallback.
  final String role;
  final bool isCheckedIn;
  final String? checkInTime;

  /// Σ delivered ÷ Σ target across the rep's (or team's) SKUs for the month.
  final TargetProgress? target;

  /// Today's route coverage (Sales Officer view).
  final RouteProgress? route;

  /// Team roll-up + per-subordinate progress (Manager view).
  final TeamSummary? team;

  /// Pending approval counts (Manager view).
  final ApprovalsSummary? approvals;

  bool get isManager => role == 'manager' || team != null;

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    return DashboardSummary(
      role: (map['role'] ?? '').toString().trim().toLowerCase(),
      isCheckedIn: asBool(map['is_checked_in']),
      checkInTime: asNullableString(map['check_in_time']),
      target: TargetProgress.fromMapOrNull(asMapOrNull(map['target'])),
      route: RouteProgress.fromMapOrNull(
        asMapOrNull(map['today_route'] ?? map['route']),
      ),
      team: TeamSummary.fromMapOrNull(asMapOrNull(map['team'])),
      approvals: ApprovalsSummary.fromMapOrNull(asMapOrNull(map['approvals'])),
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
}

class TeamMemberProgress {
  const TeamMemberProgress({
    required this.id,
    required this.name,
    required this.percent,
    required this.isCheckedIn,
  });

  final int id;
  final String name;
  final double percent;
  final bool isCheckedIn;

  double get fraction => (percent / 100).clamp(0.0, 1.0);

  factory TeamMemberProgress.fromMap(Map<String, dynamic> map) {
    return TeamMemberProgress(
      id: asInt(map['id']),
      name: (map['name'] ?? '').toString(),
      percent: asDouble(map['percent']),
      isCheckedIn: asBool(map['is_checked_in']),
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
