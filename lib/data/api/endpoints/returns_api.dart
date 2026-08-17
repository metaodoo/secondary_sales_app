// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Returns endpoints for the secondary sales API.
extension ReturnsApi on ApiService {
  Future<Map<String, dynamic>> getReturns({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? state,
    String? returnReciptStatus,
    int? distributorId,
    String? type,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (state != null && state != 'all') params['state'] = state;
    if (returnReciptStatus != null && returnReciptStatus != 'all') {
      params['return_recipt_status'] = returnReciptStatus;
    }
    if (distributorId != null) params['distributor_id'] = distributorId;
    if (type != null && type.isNotEmpty) params['type'] = type;

    final result = await _post(endpoint, params);
    if (result['success'] == true) {
      return {
        'data': List<Map<String, dynamic>>.from(result['data']),
        'total': result['meta'] != null ? result['meta']['total'] : 0,
      };
    }
    throw Exception(result['message'] ?? 'Failed to load returns');
  }

  Future<Map<String, dynamic>> prepareReturn({
    int? distributorId,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (distributorId != null) params['distributor_id'] = distributorId;

    final result = await _post(
      '$endpoint/prepare',
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
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (distributorId != null) params['distributor_id'] = distributorId;

    final result = await _post(
      '$endpoint/products',
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
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (distributorId != null) params['distributor_id'] = distributorId;

    final result = await _post(
      '$endpoint/products/$productId/lots',
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
    String? attachmentBase64,
    String? attachmentFilename,
    String endpoint = AppConstants.returnsEndpoint,
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
    if (attachmentBase64 != null && attachmentBase64.isNotEmpty) {
      params['attachment_base64'] = attachmentBase64;
    }
    if (attachmentFilename != null && attachmentFilename.isNotEmpty) {
      params['attachment_filename'] = attachmentFilename;
    }

    final result = await _post(
      '$endpoint/create',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to create return delivery');
  }

  Future<Map<String, dynamic>> getReturnDetails(
    int returnId, {
    String? type,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (type != null && type.isNotEmpty) params['type'] = type;

    final result = await _post(
      '$endpoint/$returnId',
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
    bool sendToSalesOperation = false,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'lines': lines,
      'send_to_sales_operation': sendToSalesOperation,
    };
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (challanNumber != null && challanNumber.isNotEmpty) {
      params['challan_number'] = challanNumber;
    }
    if (damageType != null && damageType.isNotEmpty) {
      params['damage_type'] = damageType;
    }

    final result = await _post(
      '$endpoint/$returnId/update',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to update return delivery');
  }

  Future<Map<String, dynamic>> returnAction(
    int returnId,
    String action, {
    String? type,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'action': action,
    };
    if (type != null && type.isNotEmpty) params['type'] = type;
    final result = await _post(
      '$endpoint/$returnId/action',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to execute return action');
  }
}

