// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Routes endpoints for the secondary sales API.
extension RoutesApi on ApiService {
  Future<Map<String, dynamic>> getVisits({
    int page = 1,
    int pageSize = 20,
    String? visitType,
    int? routeId,
    String? search,
    String? scope,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
    };
    if (visitType != null && visitType != 'all') params['visit_type'] = visitType;
    if (routeId != null) params['route_id'] = routeId;
    if (scope != null && scope.isNotEmpty) params['scope'] = scope;
    final q = search?.trim();
    if (q != null && q.isNotEmpty) params['search'] = q;
    if (dateFrom != null) {
      params['date_from'] =
          '${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    }
    if (dateTo != null) {
      params['date_to'] =
          '${dateTo.year.toString().padLeft(4, '0')}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
    }

    final result = await _post('/api/v1/visits', params);
    if (result['success'] == true) {
      return {
        'data': List<Map<String, dynamic>>.from(result['data'] ?? []),
        'pagination': Map<String, dynamic>.from(result['pagination'] ?? {}),
      };
    }
    throw Exception(result['message'] ?? 'Failed to load visits');
  }

  Future<List<Map<String, dynamic>>> getRoutes({
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
    final q = search?.trim();
    if (q != null && q.isNotEmpty) {
      params['search'] = q;
    }

    final result = await _post('/api/v1/ss/routes', params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load routes');
  }

  Future<Map<String, dynamic>> createRoute({
    required String name,
    int? distributorId,
    List<int>? employeeIds,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'name': name,
    };
    if (distributorId != null) params['distributor_id'] = distributorId;
    if (employeeIds != null) params['employee_ids'] = employeeIds;

    final result = await _post('/api/v1/ss/routes/create', params);
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create route');
  }

  Future<Map<String, dynamic>> getRouteDetail(int routeId) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};

    final result = await _post('/api/v1/ss/routes/$routeId', params);
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to load route details');
  }

  Future<Map<String, dynamic>> updateRoute(
    int routeId, {
    required String name,
    int? distributorId,
    List<int>? employeeIds,
    bool? active,
    List<Map<String, dynamic>>? outlets,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'name': name,
    };
    if (distributorId != null) params['distributor_id'] = distributorId;
    if (employeeIds != null) params['employee_ids'] = employeeIds;
    if (active != null) params['active'] = active;
    if (outlets != null) params['outlets'] = outlets;

    final result = await _post('/api/v1/ss/routes/$routeId/update', params);
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update route');
  }

  Future<Map<String, dynamic>> addOutletToRoute(
    int routeId, {
    int? outletId,
    String? name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? city,
    int? sequence,
    double? expectedVisitTime,
    double? partnerLatitude,
    double? partnerLongitude,
    String? outletOwnerName,
    String? image1920,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (outletId != null) {
      params['outlet_id'] = outletId;
    } else {
      if (name != null) params['name'] = name;
      if (mobile != null) params['mobile'] = mobile;
      if (phone != null) params['phone'] = phone;
      if (email != null) params['email'] = email;
      if (street != null) params['street'] = street;
      if (city != null) params['city'] = city;
      if (partnerLatitude != null) params['partner_latitude'] = partnerLatitude;
      if (partnerLongitude != null) {
        params['partner_longitude'] = partnerLongitude;
      }
      if (outletOwnerName != null) params['outlet_owner_name'] = outletOwnerName;
      if (image1920 != null) params['image_1920'] = image1920;
    }
    if (sequence != null) params['sequence'] = sequence;
    if (expectedVisitTime != null) {
      params['expected_visit_time'] = expectedVisitTime;
    }

    final result = await _post(
      '/api/v1/ss/routes/$routeId/outlets/add',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to add outlet to route');
  }

  Future<bool> removeOutletFromRoute(int routeId, int outletId) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    final result = await _post(
      '/api/v1/ss/routes/$routeId/outlets/$outletId/remove',
      params,
    );
    if (result['success'] == true) {
      return true;
    }
    throw Exception(result['message'] ?? 'Failed to remove outlet from route');
  }
}
