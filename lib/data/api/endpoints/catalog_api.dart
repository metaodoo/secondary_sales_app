// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Catalog endpoints for the secondary sales API.
extension CatalogApi on ApiService {
  Future<List<Product>> getProducts({String? search, String? saleType, int? partnerId}) async {
    final params = <String, dynamic>{'page_size': 100, 'active': true};
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['name'] = query;
    }
    if (saleType != null) {
      params['sale_type'] = saleType;
      params['employee_id'] = _activeEmployeeId;
    }
    if (partnerId != null) {
      params['partner_id'] = partnerId;
    }

    final result = await _post(AppConstants.productsEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['products'] ?? [];
      return data.map((json) => Product.fromMap(json)).toList();
    }
    throw Exception(
      result['error'] ?? result['message'] ?? 'Failed to load products',
    );
  }

  Future<List<Map<String, dynamic>>> getMediums() async {
    final params = <String, dynamic>{};
    final result = await _post('${AppConstants.apiPrefix}/sales/mediums', params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load order mediums');
  }

  Future<List<Warehouse>> getWarehouses({String? search}) async {
    final params = <String, dynamic>{'page_size': 100};
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }

    final result = await _post(AppConstants.warehousesEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => Warehouse.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load warehouses');
  }

  Future<List<StockLocation>> getLocations({
    String? search,
    String? usage,
    int? employeeId,
    int? distributorId,
  }) async {
    final params = <String, dynamic>{
      'page_size': 100,
      if (search != null && search.isNotEmpty) 'search': search,
      if (usage != null && usage.isNotEmpty) 'usage': usage,
      if (employeeId != null) 'employee_id': employeeId,
      if (distributorId != null) 'distributor_id': distributorId,
    };

    final result = await _post('${AppConstants.apiPrefix}/locations', params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => StockLocation.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load locations');
  }

  Future<List<AvailableLot>> getAvailableLots({
    required int productId,
    int? warehouseId,
    int? locationId,
  }) async {
    final result = await _post(
      '${AppConstants.productsEndpoint}/$productId/available-lots',
      {
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (locationId != null) 'location_id': locationId,
      },
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => AvailableLot.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load available lots');
  }
}
