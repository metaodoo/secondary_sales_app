// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Visits endpoints for the secondary sales API.
extension VisitsApi on ApiService {
  Future<Map<String, dynamic>> createVisit(
    int employeeId,
    int outletId, {
    String visitType = 'standard',
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId,
      'outlet_id': outletId,
      'visit_type': visitType,
      'check_in_time': DateTime.now().toUtc().toIso8601String(),
    };
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;

    final result = await _post(
      '${AppConstants.apiPrefix}/visits/create',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create visit');
  }

  Future<Map<String, dynamic>> updateVisit(
    int visitId, {
    String? checkOutTime,
    String? visitType,
    int? visitedWithId,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (checkOutTime != null) {
      params['check_out_time'] = checkOutTime;
    }
    if (visitType != null) {
      params['visit_type'] = visitType;
    }
    if (visitedWithId != null) {
      params['visited_with_id'] = visitedWithId;
    }

    final result = await _post(
      '${AppConstants.apiPrefix}/visits/$visitId/update',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update visit');
  }

  Future<Map<String, dynamic>> getTodayVisits(int employeeId) async {
    final params = <String, dynamic>{'employee_id': employeeId};
    final result = await _post(
      '${AppConstants.apiPrefix}/visits/today',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to get today\'s visits');
  }

  Future<List<Map<String, dynamic>>> getRouteVisitHistory(int routeId) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    final result = await _post(
      '${AppConstants.routesEndpoint}/$routeId/visits',
      params,
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load route visit history');
  }

  Future<Map<String, dynamic>> getOutletVisitHistory(int outletId) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    final result = await _post(
      '${AppConstants.apiPrefix}/contacts/$outletId/visits',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? {});
    }
    throw Exception(result['message'] ?? 'Failed to load outlet visit history');
  }

  Future<Map<String, dynamic>> startRouteVisit(int routeId) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'route_id': routeId,
    };
    final result = await _post(AppConstants.routeVisitsEndpoint, params);
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to start route visit');
  }

  Future<Map<String, dynamic>> getRouteVisitDetails(int visitId) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    final result = await _post(
      '${AppConstants.routeVisitsEndpoint}/$visitId',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to load route visit details');
  }

  Future<Map<String, dynamic>> executeRouteVisitAction({
    required int visitId,
    required String action,
    int? outletId,
    int? lineId,
    double? latitude,
    double? longitude,
    String? note,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'action': action,
    };
    if (outletId != null) params['outlet_id'] = outletId;
    if (lineId != null) params['line_id'] = lineId;
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (note != null) params['note'] = note;

    final result = await _post(
      '${AppConstants.routeVisitsEndpoint}/$visitId/action',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to execute action');
  }

  // --- Return Delivery Endpoints ---
}
