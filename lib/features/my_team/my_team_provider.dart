import 'package:flutter/material.dart';
import 'package:secondary_sales/data/api/api_service.dart';

class MyTeamMember {
  final int id;
  final String name;
  final String workEmail;
  final String? avatarUrl;
  final bool isActiveToday;
  final String attendanceStatus;
  final String? lastSyncTime;

  MyTeamMember({
    required this.id,
    required this.name,
    required this.workEmail,
    this.avatarUrl,
    required this.isActiveToday,
    required this.attendanceStatus,
    this.lastSyncTime,
  });

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
  bool _isLoading = false;
  String? _error;

  List<MyTeamMember> get teamMembers => _teamMembers;
  List<AttendanceShift> get checkpointsShifts => _checkpointsShifts;
  String? get selectedEmployeeName => _selectedEmployeeName;
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
      final res = await _apiService.getMyTeam(date: date);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final list = data['my_team'] as List? ?? [];
        _teamMembers = list.map((item) => MyTeamMember.fromMap(item as Map<String, dynamic>)).toList();
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

  Future<void> fetchEmployeeCheckpoints({
    required int employeeId,
    required String date,
  }) async {
    _isLoading = true;
    _error = null;
    _checkpointsShifts = [];
    notifyListeners();

    try {
      final res = await _apiService.getEmployeeCheckpoints(
        employeeId: employeeId,
        date: date,
      );
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        _selectedEmployeeName = data['employee']?['name'] as String?;
        final list = data['attendances'] as List? ?? [];
        _checkpointsShifts = list.map((item) => AttendanceShift.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        _error = res['message'] ?? 'Failed to retrieve employee checkpoints.';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
