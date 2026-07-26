part of '../api_service.dart';

extension LeaveApi on ApiService {
  Future<Map<String, dynamic>> getLeaveTypes(int employeeId) async {
    return _post('/api/v1/hr/leave/types', {
      'employee_id': employeeId,
    });
  }

  Future<Map<String, dynamic>> submitLeaveRequest({
    required int employeeId,
    required int leaveTypeId,
    required String dateFrom,
    required String dateTo,
    required String reason,
    String? attachment,
    String? attachmentName,
  }) async {
    return _post('/api/v1/hr/leave/request', {
      'employee_id': employeeId,
      'leave_type_id': leaveTypeId,
      'date_from': dateFrom,
      'date_to': dateTo,
      'reason': reason,
      'attachment': attachment,
      'attachment_name': attachmentName,
    });
  }

  Future<Map<String, dynamic>> getLeaveList({
    required int employeeId,
    required String tabFilter,
    String? dateFrom,
    String? dateTo,
    String? searchQuery,
  }) async {
    return _post('/api/v1/hr/leave/list', {
      'employee_id': employeeId,
      'tab_filter': tabFilter,
      'date_from': dateFrom,
      'date_to': dateTo,
      'search_query': searchQuery,
    });
  }

  /// Fetches one leave by id. Backs deep-linking from a notification, where the
  /// list has not necessarily been loaded. Returns the same item shape as
  /// [getLeaveList] plus an `attachments` array.
  Future<Map<String, dynamic>> getLeaveDetails({
    required int employeeId,
    required int leaveId,
  }) async {
    return _post('/api/v1/hr/leave/details', {
      'employee_id': employeeId,
      'leave_id': leaveId,
    });
  }

  Future<Map<String, dynamic>> submitLeaveAction({
    required int employeeId,
    required int leaveId,
    required String action, // 'approve' or 'reject'
  }) async {
    return _post('/api/v1/hr/leave/action', {
      'employee_id': employeeId,
      'leave_id': leaveId,
      'action': action,
    });
  }
}
