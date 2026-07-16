// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Deliveries endpoints for the secondary sales API.
extension DeliveriesApi on ApiService {
  Future<DeliveryPrepare> preparePrimarySaleDelivery(
    int orderId, {
    int? pickingId,
    String? saleType,
  }) async {
    final result = await _post('${AppConstants.deliveriesEndpoint}/prepare', {
      'employee_id': _activeEmployeeId,
      'sale_order_id': orderId,
      if (pickingId != null) 'picking_id': pickingId,
      if (saleType != null) 'sale_type': saleType,
    });
    if (result['success'] == true) {
      return DeliveryPrepare.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to prepare delivery');
  }

  Future<SaleOrderDetail> validatePrimarySaleDelivery({
    required int orderId,
    required int pickingId,
    int? warehouseId,
    int? locationId,
    required List<DeliveryLineInput> lines,
    bool createBackorder = true,
    String? saleType,
    String action = 'validate',
  }) async {
    final result =
        await _post('${AppConstants.deliveriesEndpoint}/$pickingId/action', {
          'employee_id': _activeEmployeeId,
          'sale_order_id': orderId,
          'action': action,
          if (warehouseId != null) 'warehouse_id': warehouseId,
          if (locationId != null) 'location_id': locationId,
          'create_backorder': createBackorder,
          'lines': lines.map((line) => line.toPayload()).toList(),
          if (saleType != null) 'sale_type': saleType,
        });
    if (result['success'] == true) {
      final data = result['data'];
      final order = data is Map ? data['order'] : null;
      return SaleOrderDetail.fromMap(
        order is Map ? order.cast<String, dynamic>() : <String, dynamic>{},
      );
    }
    throw Exception(result['message'] ?? 'Failed to validate delivery');
  }

  Future<List<DeliveryItem>> getDeliveries({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? state,
    String? type,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (state != null && state.isNotEmpty) params['state'] = state;
    if (type != null && type.isNotEmpty) params['type'] = type;

    final result = await _post(AppConstants.deliveriesEndpoint, params);
    if (result['success'] == true) {
      final data = result['data'] as List? ?? [];
      return data.map((e) => DeliveryItem.fromMap(e)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to fetch deliveries');
  }

  Future<List<AvailableLot>> getDeliveryProductLots(
    int productId, {
    required int saleOrderId,
    int? locationId,
    int? pickingId,
  }) async {
    final result = await _post(
      '${AppConstants.deliveriesEndpoint}/products/$productId/lots',
      {
        'employee_id': _activeEmployeeId,
        'sale_order_id': saleOrderId,
        if (locationId != null) 'location_id': locationId,
        if (pickingId != null) 'picking_id': pickingId,
      },
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => AvailableLot.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load delivery lots');
  }

  Future<List<DeliveryLotInput>> autoAssignDeliveryLots({
    required int productId,
    required double quantity,
    required int saleOrderId,
    int? pickingId,
    int? locationId,
  }) async {
    final result = await _post(
      '${AppConstants.deliveriesEndpoint}/products/$productId/auto-assign-lots',
      {
        'employee_id': _activeEmployeeId,
        'sale_order_id': saleOrderId,
        'quantity': quantity,
        if (pickingId != null) 'picking_id': pickingId,
        if (locationId != null) 'location_id': locationId,
      },
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) {
        final Map<String, dynamic> map = json is Map
            ? json.cast<String, dynamic>()
            : {};
        return DeliveryLotInput(
          lot: AvailableLot(
            lotId: asInt(map['lot_id']),
            lotName: map['lot_name']?.toString() ?? '',
            productId: productId,
            availableQty: asDouble(map['quantity']),
          ),
          quantity: asDouble(map['quantity']),
        );
      }).toList();
    }
    throw Exception(result['message'] ?? 'Failed to auto-assign lots');
  }
}
