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
    String scope = 'own',
    int? subordinateId,
    String? startDate,
    String? endDate,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final body = <String, dynamic>{
      'employee_id': employeeId,
      'scope': scope,
      'page': page,
      'page_size': pageSize,
    };
    if (subordinateId != null && subordinateId > 0) {
      body['subordinate_id'] = subordinateId;
    }
    if (startDate != null && startDate.isNotEmpty) {
      body['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      body['end_date'] = endDate;
    }
    if (search != null && search.trim().isNotEmpty) {
      body['search'] = search.trim();
    }
    return _post('/api/v1/hr/attendance/history', body);
  }

  Future<Map<String, dynamic>> submitAttendanceAction({
    required int employeeId,
    required String action, // "check_in" or "check_out"
    required double latitude,
    required double longitude,
    String? checkInImage,
  }) async {
    return _post('/api/v1/hr/attendance/action', {
      'employee_id': employeeId,
      'action': action,
      'latitude': latitude,
      'longitude': longitude,
      'check_in_image': checkInImage,
    });
  }
}
