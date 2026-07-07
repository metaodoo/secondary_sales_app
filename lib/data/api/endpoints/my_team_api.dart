// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

extension MyTeamApi on ApiService {
  Future<Map<String, dynamic>> getMyTeam({String? date}) async {
    return _post('/api/v1/manager/my_team', {
      if (date != null) 'date': date,
    });
  }

  Future<Map<String, dynamic>> getEmployeeCheckpoints({
    required int employeeId,
    required String date,
  }) async {
    return _post('/api/v1/manager/employee/checkpoints', {
      'employee_id': employeeId,
      'date': date,
    });
  }
}
