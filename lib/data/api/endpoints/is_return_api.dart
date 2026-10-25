part of '../api_service.dart';

extension IsReturnApi on ApiService {
  Future<Map<String, dynamic>> getIsReturns({
    String? category,
    String? state,
    String? search,
    int? partnerId,
  }) async {
    final result = await _post(AppConstants.isReturnsEndpoint, {
      if (category != null && category != 'all') 'return_category': category,
      if (state != null && state != 'all') 'state': state,
      if (search != null && search.isNotEmpty) 'search': search,
      if (partnerId != null) 'partner_id': partnerId,
      'page': 1,
      'page_size': 50,
    });
    if (result['success'] == true) return asMap(result['data']);
    throw Exception(result['message'] ?? 'Failed to load returns');
  }

  Future<Map<String, dynamic>> createIsReturn(Map<String, dynamic> payload) async {
    final result = await _post(AppConstants.isReturnsCreateEndpoint, payload);
    if (result['success'] == true) return asMap(result['data']);
    throw Exception(result['message'] ?? 'Failed to create return');
  }

  Future<Map<String, dynamic>> isReturnAction(
    int returnId,
    String action, {
    List<Map<String, dynamic>>? lines,
  }) async {
    final result = await _post('${AppConstants.isReturnsEndpoint}/$returnId/action', {
      'action': action,
      'lines': ?lines,
    });
    if (result['success'] == true) return asMap(result['data']);
    throw Exception(result['message'] ?? 'Failed to update return');
  }

  Future<List<Map<String, dynamic>>> getIsReturnCustomers({String? search}) async {
    final result = await _post(AppConstants.isReturnsCustomersEndpoint, {
      'page': 1,
      'page_size': 50,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) return data.map((row) => asMap(row)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load customers');
  }

  Future<List<Map<String, dynamic>>> getIsReturnCategories() async {
    final result = await _post('${AppConstants.isReturnsProductsEndpoint}/categories', {});
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) return data.map((row) => asMap(row)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load categories');
  }

  Future<List<Map<String, dynamic>>> getIsReturnProducts({String? search, int? appCategoryId}) async {
    final result = await _post(AppConstants.isReturnsProductsEndpoint, {
      if (search != null && search.isNotEmpty) 'search': search,
      if (appCategoryId != null) 'app_categ_id': appCategoryId,
    });
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) return data.map((row) => asMap(row)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load products');
  }

  Future<List<Map<String, dynamic>>> getIsReturnLots(int productId, {String? search}) async {
    final result = await _post('${AppConstants.isReturnsProductsEndpoint}/$productId/lots', {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    if (result['success'] == true) {
      final data = result['data'];
      if (data is List) return data.map((row) => asMap(row)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load batches');
  }
}
