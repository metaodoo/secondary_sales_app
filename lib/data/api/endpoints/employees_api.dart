// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Employees endpoints for the secondary sales API.
extension EmployeesApi on ApiService {
  Future<List<SalesEmployee>> getSubordinateOfficers({
    int? routeId,
    int? outletId,
  }) async {
    final params = <String, dynamic>{
      'page_size': 100,
      'manager_id': _activeEmployeeId,
      if (routeId != null) 'route_id': routeId,
      if (outletId != null) 'outlet_id': outletId,
    };
    final result = await _post('${AppConstants.apiPrefix}/employees', params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => SalesEmployee.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load officers');
  }

  Future<List<SalesEmployee>> getEmployees({
    int? distributorId,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page_size': 100,
    };
    if (distributorId != null) {
      params['distributor_id'] = distributorId;
    }
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }

    final result = await _post(AppConstants.employeesEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => SalesEmployee.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load employees');
  }

  Future<SalesEmployee> createEmployee({
    required String name,
    String? email,
    String? phone,
    String? workPhone,
    String? jobTitle,
    required int distributorId,
    List<int>? assignedRouteIds,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (workPhone != null) 'work_phone': workPhone,
      if (jobTitle != null) 'job_title': jobTitle,
      'distributor_id': distributorId,
      if (assignedRouteIds != null) 'assigned_route_ids': assignedRouteIds,
    };

    final result = await _post(
      '${AppConstants.employeesEndpoint}/create',
      params,
    );
    if (result['success'] == true) {
      return SalesEmployee.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create employee');
  }

  Future<SalesEmployee> updateEmployee(
    int employeeId, {
    String? name,
    String? email,
    String? phone,
    String? workPhone,
    String? jobTitle,
    int? distributorId,
    List<int>? assignedRouteIds,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (workPhone != null) 'work_phone': workPhone,
      if (jobTitle != null) 'job_title': jobTitle,
      if (distributorId != null) 'distributor_id': distributorId,
      if (assignedRouteIds != null) 'assigned_route_ids': assignedRouteIds,
    };

    final result = await _post(
      '${AppConstants.employeesEndpoint}/$employeeId/update',
      params,
    );
    if (result['success'] == true) {
      return SalesEmployee.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update employee');
  }

  Future<SalesEmployee> getEmployee(int employeeId) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};

    final result = await _post(
      '${AppConstants.employeesEndpoint}/$employeeId',
      params,
    );
    if (result['success'] == true) {
      return SalesEmployee.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to load employee details');
  }
}
