// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

extension AttendanceApi on ApiService {
  Future<Map<String, dynamic>> getAttendanceStatus(int employeeId) async {
    return _post('/api/v1/hr/attendance/status', {
      'employee_id': employeeId,
    });
  }

  Future<Map<String, dynamic>> getAttendanceHistory({
    required int employeeId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return _post('/api/v1/hr/attendance/history', {
      'employee_id': employeeId,
      'page': page,
      'page_size': pageSize,
    });
  }

  Future<Map<String, dynamic>> submitAttendanceAction({
    required int employeeId,
    required String action, // "check_in" or "check_out"
    required double latitude,
    required double longitude,
  }) async {
    return _post('/api/v1/hr/attendance/action', {
      'employee_id': employeeId,
      'action': action,
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
