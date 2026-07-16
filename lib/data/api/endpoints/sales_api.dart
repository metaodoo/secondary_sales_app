// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Sales endpoints for the secondary sales API.
extension SalesApi on ApiService {
  Future<List<PrimaryOrder>> getRecentOrders({
    String? search,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String saleType = 'primary',
    int? outletId,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'sale_type': saleType,
      'page_size': 20,
    };
    if (outletId != null) {
      params['outlet_id'] = outletId;
    }
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      params['state'] = status;
    }
    if (dateFrom != null) {
      params['date_from'] =
          '${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    }
    if (dateTo != null) {
      params['date_to'] =
          '${dateTo.year.toString().padLeft(4, '0')}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
    }

    final result = await _post(AppConstants.saleOrdersEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => PrimaryOrder.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load orders');
  }

  Future<SaleOrderDetail> getPrimarySaleOrderDetail(int orderId, {String saleType = 'primary'}) async {
    final result = await _post('${AppConstants.saleOrdersEndpoint}/$orderId', {
      'employee_id': _activeEmployeeId,
      'sale_type': saleType,
    });
    if (result['success'] == true) {
      return SaleOrderDetail.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to load order detail');
  }

  Future<SaleOrderDetail> cancelPrimarySaleOrder(int orderId, {String saleType = 'primary'}) async {
    final result = await _post(
      '${AppConstants.saleOrdersEndpoint}/$orderId/action',
      {
        'employee_id': _activeEmployeeId,
        'sale_type': saleType,
        'action': 'cancel',
      },
    );
    if (result['success'] == true) {
      return SaleOrderDetail.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to cancel order');
  }

  Future<SaleOrderDetail> confirmPrimarySaleOrder(int orderId, {String saleType = 'primary'}) async {
    final result = await _post(
      '${AppConstants.saleOrdersEndpoint}/$orderId/action',
      {
        'employee_id': _activeEmployeeId,
        'sale_type': saleType,
        'action': 'confirm',
      },
    );
    if (result['success'] == true) {
      return SaleOrderDetail.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to confirm order');
  }

  Future<Map<String, dynamic>> printPrimarySaleOrder(int orderId, {String saleType = 'primary'}) async {
    final result = await _post(
      '${AppConstants.saleOrdersEndpoint}/$orderId/print',
      {'employee_id': _activeEmployeeId, 'sale_type': saleType},
    );
    if (result['success'] == true) {
      return result['data'] ?? <String, dynamic>{};
    }
    throw Exception(result['message'] ?? 'Failed to print order');
  }

  Future<PrimaryOrder> createPrimarySalesOrder({
    required int hubId,
    required List<Map<String, dynamic>> items,
    required DateTime expectedDeliveryDate,
    bool confirm = true,
    int? warehouseId,
  }) async {
    final params = {
      'employee_id': _activeEmployeeId,
      'sale_type': 'primary',
      'distributor_id': hubId,
      'order_lines': items.map((item) {
        final Product product = item['product'];
        return {
          'product_id': product.id,
          'product_uom_qty': item['quantity'],
          'price_unit': product.price,
          'discount': item['discount'] ?? 0,
        };
      }).toList(),
      'expected_delivery_date':
          '${expectedDeliveryDate.year.toString().padLeft(4, '0')}-${expectedDeliveryDate.month.toString().padLeft(2, '0')}-${expectedDeliveryDate.day.toString().padLeft(2, '0')}',
      'confirm': confirm,
    };
    if (warehouseId != null) {
      params['warehouse_id'] = warehouseId;
    }

    final result = await _post(AppConstants.createSaleOrderEndpoint, params);
    if (result['success'] == true) {
      return PrimaryOrder.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create primary sale order');
  }

  Future<Map<String, dynamic>> createSecondarySaleOrder({
    required int outletId,
    required List<Map<String, dynamic>> items,
    int? mediumId,
    int? routeId,
    int? visitId,
    bool confirm = true,
  }) async {
    final params = {
      'employee_id': _activeEmployeeId,
      'sale_type': 'secondary',
      'outlet_id': outletId,
      'confirm': confirm,
      'order_lines': items.map((item) {
        return {
          'product_id': item['product_id'],
          'product_uom_qty': item['order_qty'],
          'damaged_qty': item['damaged_qty'],
          'price_unit': item['price_unit'],
        };
      }).toList(),
    };
    if (mediumId != null) params['medium_id'] = mediumId;
    if (routeId != null) params['route_id'] = routeId;
    if (visitId != null) params['visit_id'] = visitId;

    final result = await _post(AppConstants.createSaleOrderEndpoint, params);
    if (result['success'] == true) {
      return result['data'] ?? <String, dynamic>{};
    }
    throw Exception(result['message'] ?? 'Failed to create secondary sale order');
  }

  Future<PrimaryOrder> updateSalesOrder({
    required int orderId,
    required int hubId,
    required List<Map<String, dynamic>> items,
    required DateTime expectedDeliveryDate,
    bool confirm = true,
    int? warehouseId,
  }) async {
    final params = {
      'employee_id': _activeEmployeeId,
      'distributor_id': hubId,
      'order_lines': items.map((item) {
        final Product product = item['product'];
        return {
          'product_id': product.id,
          'product_uom_qty': item['quantity'],
          'price_unit': product.price,
          'discount': item['discount'] ?? 0.0,
        };
      }).toList(),
      'expected_delivery_date':
          '${expectedDeliveryDate.year.toString().padLeft(4, '0')}-${expectedDeliveryDate.month.toString().padLeft(2, '0')}-${expectedDeliveryDate.day.toString().padLeft(2, '0')}',
      'confirm': confirm,
    };
    if (warehouseId != null) {
      params['warehouse_id'] = warehouseId;
    }

    final result = await _post(
      '${AppConstants.apiPrefix}/sale-orders/$orderId/update',
      params,
    );
    if (result['success'] == true) {
      return PrimaryOrder.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update sale order');
  }

  Future<Map<String, dynamic>> updateSecondarySaleOrder({
    required int orderId,
    required int outletId,
    required List<Map<String, dynamic>> items,
    int? mediumId,
    int? routeId,
    int? visitId,
    bool confirm = true,
  }) async {
    final params = {
      'employee_id': _activeEmployeeId,
      'sale_type': 'secondary',
      'outlet_id': outletId,
      'confirm': confirm,
      'order_lines': items.map((item) {
        return {
          'product_id': item['product_id'],
          'product_uom_qty': item['order_qty'],
          'damaged_qty': item['damaged_qty'],
          'price_unit': item['price_unit'],
        };
      }).toList(),
    };
    if (mediumId != null) params['medium_id'] = mediumId;
    if (routeId != null) params['route_id'] = routeId;
    if (visitId != null) params['visit_id'] = visitId;

    final result = await _post(
      '${AppConstants.apiPrefix}/sale-orders/$orderId/update',
      params,
    );
    if (result['success'] == true) {
      return result['data'] ?? <String, dynamic>{};
    }
    throw Exception(result['message'] ?? 'Failed to update secondary sale order');
  }
}
