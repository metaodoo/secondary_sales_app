// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Scraps endpoints for the secondary sales API.
extension ScrapsApi on ApiService {
  Future<Map<String, dynamic>> getScraps({
    int page = 1,
    int pageSize = 20,
    String state = 'all',
    String? search,
    String? type,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
      'state': state,
    };
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (type != null && type.isNotEmpty) {
      params['type'] = type;
    }

    final result = await _post(AppConstants.scrapsEndpoint, params);
    if (result['success'] == true) {
      return {
        'data': List<Map<String, dynamic>>.from(result['data']),
        'meta': Map<String, dynamic>.from(result['meta']),
      };
    }
    throw Exception(result['message'] ?? 'Failed to fetch scrap deliveries');
  }

  Future<Map<String, dynamic>> prepareScrap({int? distributorId}) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (distributorId != null) params['distributor_id'] = distributorId;

    final result = await _post(
      '${AppConstants.scrapsEndpoint}/prepare',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to prepare scrap context');
  }

  Future<List<Map<String, dynamic>>> getScrapProducts({
    String? search,
    int? distributorId,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (distributorId != null) {
      params['distributor_id'] = distributorId;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final result = await _post(
      '${AppConstants.scrapsEndpoint}/products',
      params,
    );
    if (result['success'] == true) {
      return List<Map<String, dynamic>>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to fetch scrap products');
  }

  Future<Map<String, dynamic>> getScrapProductLots(
    int productId, {
    int? distributorId,
  }) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (distributorId != null) {
      params['distributor_id'] = distributorId;
    }
    final result = await _post(
      '${AppConstants.scrapsEndpoint}/products/$productId/lots',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to fetch lot details');
  }

  Future<Map<String, dynamic>> createScrap({
    required List<Map<String, dynamic>> lines,
    int? distributorId,
    String? type,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'lines': lines,
    };
    if (distributorId != null) {
      params['distributor_id'] = distributorId;
    }
    if (type != null && type.isNotEmpty) {
      params['type'] = type;
    }

    final result = await _post('${AppConstants.scrapsEndpoint}/create', params);
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to create scrap delivery');
  }

  Future<Map<String, dynamic>> getScrapDetails(int scrapId, {String? type}) async {
    final params = <String, dynamic>{'employee_id': _activeEmployeeId};
    if (type != null && type.isNotEmpty) params['type'] = type;
    final result = await _post(
      '${AppConstants.scrapsEndpoint}/$scrapId',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to load scrap details');
  }

  Future<Map<String, dynamic>> updateScrap(
    int scrapId, {
    required List<Map<String, dynamic>> lines,
    String? type,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'lines': lines,
    };
    if (type != null && type.isNotEmpty) params['type'] = type;

    final result = await _post(
      '${AppConstants.scrapsEndpoint}/$scrapId/update',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }
    throw Exception(result['message'] ?? 'Failed to update scrap delivery');
  }
}
