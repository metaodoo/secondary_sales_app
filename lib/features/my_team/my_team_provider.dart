import 'package:flutter/material.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/dashboard/dashboard_summary.dart';

class MyTeamMember {
  final int id;
  final String name;
  final String workEmail;
  final String? avatarUrl;
  final bool isActiveToday;
  final String attendanceStatus;
  final String? lastSyncTime;
  final double achievedQty;
  final double targetQty;

  MyTeamMember({
    required this.id,
    required this.name,
    required this.workEmail,
    this.avatarUrl,
    required this.isActiveToday,
    required this.attendanceStatus,
    this.lastSyncTime,
    this.achievedQty = 0,
    this.targetQty = 0,
  });

  bool get hasSalesProgress => targetQty > 0 || achievedQty > 0;
  double get salesPercent =>
      targetQty <= 0 ? 0 : (achievedQty / targetQty * 100);
  double get salesFraction =>
      targetQty <= 0 ? 0 : (achievedQty / targetQty).clamp(0.0, 1.0);

  MyTeamMember copyWith({
    int? id,
    String? name,
    String? workEmail,
    String? avatarUrl,
    bool? isActiveToday,
    String? attendanceStatus,
    String? lastSyncTime,
    double? achievedQty,
    double? targetQty,
  }) {
    return MyTeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      workEmail: workEmail ?? this.workEmail,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActiveToday: isActiveToday ?? this.isActiveToday,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      achievedQty: achievedQty ?? this.achievedQty,
      targetQty: targetQty ?? this.targetQty,
    );
  }

  factory MyTeamMember.fromMap(Map<String, dynamic> map) {
    return MyTeamMember(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      workEmail: map['work_email'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      isActiveToday: map['is_active_today'] as bool? ?? false,
      attendanceStatus: map['attendance_status'] as String? ?? '',
      lastSyncTime: map['last_sync_time'] as String?,
    );
  }
}

class Checkpoint {
  final int id;
  final double latitude;
  final double longitude;
  final String? recordedAt;
  final bool isMock;

  Checkpoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.recordedAt,
    required this.isMock,
  });

  factory Checkpoint.fromMap(Map<String, dynamic> map) {
    return Checkpoint(
      id: map['id'] as int,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      recordedAt: map['recorded_at'] as String?,
      isMock: map['is_mock'] as bool? ?? false,
    );
  }
}

class AttendanceShift {
  final int id;
  final String? checkIn;
  final String? checkOut;
  final List<Checkpoint> checkpoints;

  AttendanceShift({
    required this.id,
    this.checkIn,
    this.checkOut,
    required this.checkpoints,
  });

  factory AttendanceShift.fromMap(Map<String, dynamic> map) {
    final checkpointsRaw = map['checkpoints'] as List? ?? [];
    return AttendanceShift(
      id: map['id'] as int,
      checkIn: map['check_in'] as String?,
      checkOut: map['check_out'] as String?,
      checkpoints: checkpointsRaw
          .map((pt) => Checkpoint.fromMap(pt as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MyTeamProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<MyTeamMember> _teamMembers = [];
  List<AttendanceShift> _checkpointsShifts = [];
  String? _selectedEmployeeName;
  String? _barikoiApiKey;
  bool _isLoading = false;
  String? _error;

  /// Guards against out-of-order checkpoint responses. Switching dates quickly
  /// leaves two requests in flight; without this the slower (older) one lands
  /// last and paints the wrong day's route.
  int _checkpointsRequestId = 0;

  List<MyTeamMember> get teamMembers => _teamMembers;
  List<AttendanceShift> get checkpointsShifts => _checkpointsShifts;
  String? get selectedEmployeeName => _selectedEmployeeName;
  String? get barikoiApiKey => _barikoiApiKey;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);
  }

  Future<void> fetchMyTeam({String? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resFuture = _apiService.getMyTeam(date: date);
      final progressFuture = _fetchProgressByEmployee(date: date);
      final res = await resFuture;
      final progressByEmployee = await progressFuture;
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final list = data['my_team'] as List? ?? [];
        _teamMembers = list
            .map((item) => MyTeamMember.fromMap(item as Map<String, dynamic>))
            .map((member) {
              final progress = progressByEmployee[member.id];
              if (progress == null) return member;
              return member.copyWith(
                achievedQty: progress.achievedQty,
                targetQty: progress.targetQty,
              );
            })
            .toList();
      } else {
        _error = res['message'] ?? 'Failed to retrieve team directory.';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<int, TeamMemberProgress>> _fetchProgressByEmployee({
    String? date,
  }) async {
    try {
      final day = date != null ? DateTime.tryParse(date) : DateTime.now();
      if (day == null) return const <int, TeamMemberProgress>{};

      final summary = await _apiService.getDashboardSummary(
        preset: 'custom',
        dateFrom: day,
        dateTo: day,
      );

      return {for (final report in summary.reportMembers) report.id: report};
    } catch (_) {
      // The team directory still works without sales progress; keep it best-effort.
      return const <int, TeamMemberProgress>{};
    }
  }

  /// Resolves an address via Barikoi (server-side). Returns null on any
  /// failure so callers can fall back to their own placeholder text.
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await _apiService.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final address = data['address'] as String?;
        if (address != null && address.isNotEmpty) return address;
      }
    } catch (_) {
      // Address resolution is best-effort; never surface as a screen error.
    }
    return null;
  }

  Future<void> fetchEmployeeCheckpoints({
    required int employeeId,
    required String date,
  }) async {
    final requestId = ++_checkpointsRequestId;

    _isLoading = true;
    _error = null;
    _checkpointsShifts = [];
    notifyListeners();

    try {
      final res = await _apiService.getEmployeeCheckpoints(
        employeeId: employeeId,
        date: date,
      );
      if (requestId != _checkpointsRequestId) return; // superseded
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        _selectedEmployeeName = data['employee']?['name'] as String?;
        _barikoiApiKey = data['barikoi_api_key'] as String?;
        final list = data['attendances'] as List? ?? [];
        _checkpointsShifts = list
            .map(
              (item) => AttendanceShift.fromMap(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        _error = res['message'] ?? 'Failed to retrieve employee checkpoints.';
      }
    } catch (e) {
      if (requestId != _checkpointsRequestId) return; // superseded
      _error = e.toString();
    } finally {
      if (requestId == _checkpointsRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
