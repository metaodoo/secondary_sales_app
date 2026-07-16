// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Returns endpoints for the secondary sales API.
extension ReturnsApi on ApiService {
  Future<Map<String, dynamic>> getReturns({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? state,
    int? distributorId,
    String? type,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (state != null && state != 'all') params['state'] = state;
    if (distributorId != null) params['distributor_id'] = distributorId;
    if (type != null && type.isNotEmpty) params['type'] = type;

    final result = await _post(AppConstants.returnsEndpoint, params);
    if (result['success'] == true) {
      return {
        'data': List<Map<String, dynamic>>.from(result['data']),
        'total': result['meta'] != null ? result['meta']['total'] : 0,
      };
    }
    throw Exception(result['message'] ?? 'Failed to load returns');
  }

  Future<Map<String, dynamic>> prepareReturn({int? distributorId}) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (distributorId != null) params['distributor_id'] = distributorId;

    final result = await _post(
      '${AppConstants.returnsEndpoint}/prepare',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to prepare return');
  }

  Future<List<Map<String, dynamic>>> getReturnProducts({
    String? search,
    int? distributorId,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (distributorId != null) params['distributor_id'] = distributorId;

    final result = await _post(
      '${AppConstants.returnsEndpoint}/products',
      params,
    );
    if (result['success'] == true) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to load return products');
  }

  Future<Map<String, dynamic>> getReturnProductLots(
    int productId, {
    int? distributorId,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (distributorId != null) params['distributor_id'] = distributorId;

    final result = await _post(
      '${AppConstants.returnsEndpoint}/products/$productId/lots',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to load product lots');
  }

  Future<Map<String, dynamic>> createReturn({
    required List<Map<String, dynamic>> lines,
    int? distributorId,
    String? type,
    String? challanNumber,
    String? damageType,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'lines': lines,
    };
    if (distributorId != null) params['distributor_id'] = distributorId;
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (challanNumber != null && challanNumber.isNotEmpty) {
      params['challan_number'] = challanNumber;
    }
    if (damageType != null && damageType.isNotEmpty) {
      params['damage_type'] = damageType;
    }

    final result = await _post(
      '${AppConstants.returnsEndpoint}/create',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to create return delivery');
  }

  Future<Map<String, dynamic>> getReturnDetails(int returnId, {String? type}) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (type != null && type.isNotEmpty) params['type'] = type;

    final result = await _post(
      '${AppConstants.returnsEndpoint}/$returnId',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to load return details');
  }

  Future<Map<String, dynamic>> updateReturn(
    int returnId, {
    required List<Map<String, dynamic>> lines,
    String? type,
    String? challanNumber,
    String? damageType,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'lines': lines,
    };
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (challanNumber != null && challanNumber.isNotEmpty) {
      params['challan_number'] = challanNumber;
    }
    if (damageType != null && damageType.isNotEmpty) {
      params['damage_type'] = damageType;
    }

    final result = await _post(
      '${AppConstants.returnsEndpoint}/$returnId/update',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to update return delivery');
  }

  Future<Map<String, dynamic>> returnAction(int returnId, String action) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'action': action,
    };
    final result = await _post(
      '${AppConstants.returnsEndpoint}/$returnId/action',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to execute return action');
  }
}

