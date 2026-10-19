part of '../api_service.dart';

extension CsReturnApi on ApiService {
  Future<Map<String, dynamic>> getCsReturns({
    String? category,
    String? state,
    String? search,
    int? partnerId,
    String? dateFrom,
    String? dateTo,
    String? order,
  }) async {
    final result = await _post(AppConstants.csReturnsEndpoint, {
      if (category != null && category != 'all') 'return_category': category,
      if (state != null && state != 'all') 'state': state,
      if (search != null && search.isNotEmpty) 'search': search,
      if (partnerId != null) 'partner_id': partnerId,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (order != null) 'order': order,
      'page': 1,
      'page_size': 50,
    });
    if (result['success'] == true) return asMap(result['data']);
    throw Exception(result['message'] ?? 'Failed to load returns');
  }

  Future<Map<String, dynamic>> createCsReturn(Map<String, dynamic> payload) async {
    final result = await _post(AppConstants.csReturnsCreateEndpoint, payload);
    if (result['success'] == true) return asMap(result['data']);
    throw Exception(result['message'] ?? 'Failed to create return');
  }

  Future<Map<String, dynamic>> csReturnAction(
    int returnId,
    String action, {
    List<Map<String, dynamic>>? lines,
  }) async {
    final result = await _post('${AppConstants.csReturnsEndpoint}/$returnId/action', {
      'action': action,
      'lines': ?lines,
    });
    if (result['success'] == true) return asMap(result['data']);
    throw Exception(result['message'] ?? 'Failed to update return');
  }

  Future<List<Map<String, dynamic>>> getCsReturnCustomers({String? search}) async {
    final result = await _post(AppConstants.csReturnsCustomersEndpoint, {
      'page': 1,
      'page_size': 50,
      'active': true,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) return data.map((row) => asMap(row)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load customers');
  }

  Future<List<Map<String, dynamic>>> getCsReturnCategories() async {
    final result = await _post('${AppConstants.csReturnsProductsEndpoint}/categories', {});
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) return data.map((row) => asMap(row)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load categories');
  }

  Future<List<Map<String, dynamic>>> getCsReturnProducts({String? search, int? appCategoryId}) async {
    final result = await _post(AppConstants.csReturnsProductsEndpoint, {
      if (search != null && search.isNotEmpty) 'search': search,
      if (appCategoryId != null) 'app_categ_id': appCategoryId,
    });
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) {
        return data.map((row) => asMap(row)).toList();
      }
    }
    throw Exception(result['message'] ?? 'Failed to load products');
  }

  Future<List<Map<String, dynamic>>> getCsReturnLots(int productId, {String? search}) async {
    final result = await _post('${AppConstants.csReturnsProductsEndpoint}/$productId/lots', {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) return data.map((row) => asMap(row)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load batches');
  }
}
