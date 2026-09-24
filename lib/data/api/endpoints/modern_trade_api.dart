// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Modern Trade (MT / PJP) endpoints for the mobile API.
extension ModernTradeApi on ApiService {
  /// Fetch MT / PJP outlets for an employee (recommended vs allowed)
  Future<Map<String, dynamic>> getMtOutlets({
    int? employeeId,
    String? date,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId ?? _activeEmployeeId,
      if (date != null) 'date': date,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/outlets',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to fetch Modern Trade outlets');
  }

  /// Create a justification request for an off-schedule store visit
  Future<Map<String, dynamic>> createMtJustification({
    required int outletId,
    required String reason,
    int? employeeId,
    double? latitude,
    double? longitude,
    String? checkInTime,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId ?? _activeEmployeeId,
      'outlet_id': outletId,
      'reason': reason,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (checkInTime != null) 'check_in_time': checkInTime,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/justification/create',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to submit justification');
  }

  /// Create a Modern Trade Direct Sale Order
  Future<Map<String, dynamic>> createMtSaleOrder({
    required int outletId,
    required List<Map<String, dynamic>> orderLines,
    int? visitId,
    int? employeeId,
    int? mediumId,
    bool confirm = false,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId ?? _activeEmployeeId,
      'outlet_id': outletId,
      'business_type': 'mt',
      'sale_type': 'primary',
      'order_lines': orderLines,
      'confirm': confirm,
      if (visitId != null) 'visit_id': visitId,
      if (mediumId != null) 'medium_id': mediumId,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/sale-orders/create',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create MT sales order');
  }

  /// Fetch Modern Trade Stock Audits
  Future<({List<MtStockAudit> audits, int total})> getStockAudits({
    int page = 1,
    int pageSize = 20,
    int? outletId,
    int? employeeId,
    String? type,
    String? state,
    String? date,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId ?? _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
      if (outletId != null) 'outlet_id': outletId,
      if (type != null && type != 'all') 'type': type,
      if (state != null && state != 'all') 'state': state,
      if (date != null) 'date': date,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/stock-audits',
      params,
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      final audits = data.map((json) => MtStockAudit.fromMap(json)).toList();
      final pagination = result['pagination'] is Map ? result['pagination'] as Map : null;
      final total = pagination != null ? asInt(pagination['total']) : audits.length;
      return (audits: audits, total: total);
    }
    throw Exception(result['message'] ?? 'Failed to fetch stock audits');
  }

  /// Fetch a single Stock Audit details with lines
  Future<MtStockAudit> getStockAuditDetail(int auditId) async {
    final result = await _post(
      '${AppConstants.apiPrefix}/mt/stock-audits/$auditId',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return MtStockAudit.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to fetch stock audit details');
  }

  /// Create a new Stock Audit
  Future<MtStockAudit> createStockAudit({
    required int outletId,
    required String type,
    required List<Map<String, dynamic>> lines,
    int? visitId,
    int? employeeId,
    String? notes,
    bool confirm = false,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId ?? _activeEmployeeId,
      'outlet_id': outletId,
      'type': type,
      'lines': lines,
      'confirm': confirm,
      if (visitId != null) 'visit_id': visitId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/stock-audits/create',
      params,
    );
    if (result['success'] == true) {
      return MtStockAudit.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create stock audit');
  }

  /// Update an existing draft Stock Audit
  Future<MtStockAudit> updateStockAudit({
    required int auditId,
    required int outletId,
    required String type,
    required List<Map<String, dynamic>> lines,
    int? visitId,
    int? employeeId,
    String? notes,
    bool confirm = false,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId ?? _activeEmployeeId,
      'outlet_id': outletId,
      'type': type,
      'lines': lines,
      'confirm': confirm,
      if (visitId != null) 'visit_id': visitId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/stock-audits/$auditId/update',
      params,
    );
    if (result['success'] == true) {
      return MtStockAudit.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update stock audit');
  }

  /// Confirm a draft Stock Audit
  Future<MtStockAudit> confirmStockAudit(int auditId) async {
    final result = await _post(
      '${AppConstants.apiPrefix}/mt/stock-audits/$auditId/confirm',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return MtStockAudit.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to confirm stock audit');
  }

  /// Reset a confirmed Stock Audit to draft
  Future<MtStockAudit> resetStockAudit(int auditId) async {
    final result = await _post(
      '${AppConstants.apiPrefix}/mt/stock-audits/$auditId/reset',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return MtStockAudit.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to reset stock audit');
  }

  /// Fetch saleable products and lots with expiry dates for MT audit
  Future<List<MtStockAuditProduct>> getStockAuditProducts({
    int? outletId,
    String? search,
    int? categoryId,
    int page = 1,
    int pageSize = 1000,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
      if (outletId != null) 'outlet_id': outletId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category_id': categoryId,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/stock-audits/products',
      params,
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => MtStockAuditProduct.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to fetch audit products');
  }

  /// Fetch MT daily secondary sales orders
  Future<({List<MtSecSaleOrder> orders, int total})> getMtSecondarySales({
    int page = 1,
    int pageSize = 20,
    int? outletId,
    int? employeeId,
    String? date,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'employee_id': employeeId ?? _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
      if (outletId != null) 'outlet_id': outletId,
      if (date != null) 'date': date,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/secondary-sales',
      params,
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      final orders = data.map((json) => MtSecSaleOrder.fromMap(json)).toList();
      final pagination = result['pagination'] is Map ? result['pagination'] as Map : null;
      final total = pagination != null ? asInt(pagination['total']) : orders.length;
      return (orders: orders, total: total);
    }
    throw Exception(result['message'] ?? 'Failed to fetch MT secondary sales');
  }

  /// Fetch a single MT secondary sales order details with lines
  Future<MtSecSaleOrder> getMtSecondarySaleDetail(int orderId) async {
    final result = await _post(
      '${AppConstants.apiPrefix}/mt/secondary-sales/$orderId',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return MtSecSaleOrder.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to fetch MT secondary sale details');
  }

  // ==========================================
  // Modern Trade Returns Endpoints
  // ==========================================

  /// Fetch list of Modern Trade return requests
  Future<({List<MtReturnRequest> returns, int total})> getMtReturns({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? state,
    String? returnBucket,
    int? partnerId,
    String? date,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page': page,
      'page_size': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (state != null && state != 'all') 'state': state,
      if (returnBucket != null && returnBucket != 'all') 'return_bucket': returnBucket,
      if (partnerId != null) 'partner_id': partnerId,
      if (date != null) 'date': date,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns',
      params,
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      final returns = data.map((json) => MtReturnRequest.fromMap(json)).toList();
      final pagination = result['pagination'] is Map ? result['pagination'] as Map : null;
      final total = pagination != null ? asInt(pagination['total']) : returns.length;
      return (returns: returns, total: total);
    }
    throw Exception(result['message'] ?? 'Failed to fetch MT return requests');
  }

  /// Fetch details of a single Return Request
  Future<MtReturnRequest> getMtReturnDetail(int returnId) async {
    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns/$returnId',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return MtReturnRequest.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to fetch return request details');
  }

  /// Prepare metadata for creating a new return request
  Future<Map<String, dynamic>> prepareMtReturn({int? partnerId}) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      if (partnerId != null) 'partner_id': partnerId,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns/prepare',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to prepare MT return context');
  }

  /// Create a new Return Request
  Future<MtReturnRequest> createMtReturn({
    required int partnerId,
    required String returnBucket,
    String? date,
    bool autoSubmit = false,
    required List<Map<String, dynamic>> lines,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'partner_id': partnerId,
      'return_bucket': returnBucket,
      'auto_submit': autoSubmit,
      'lines': lines,
      if (date != null) 'date': date,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns/create',
      params,
    );
    if (result['success'] == true) {
      return MtReturnRequest.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create return request');
  }

  /// Update lines of an active Return Request
  Future<MtReturnRequest> updateMtReturn(
    int returnId, {
    required List<Map<String, dynamic>> lines,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'lines': lines,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns/$returnId/update',
      params,
    );
    if (result['success'] == true) {
      return MtReturnRequest.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update return request');
  }

  /// Execute stage transition, confirm, or reset action on Return Request
  Future<MtReturnRequest> executeMtReturnAction(
    int returnId, {
    required String action,
    List<Map<String, dynamic>>? lines,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'action': action,
      if (lines != null) 'lines': lines,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns/$returnId/action',
      params,
    );
    if (result['success'] == true) {
      return MtReturnRequest.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to execute return action');
  }

  /// Fetch products for Modern Trade return requests
  Future<List<Map<String, dynamic>>> getMtReturnProducts({String? search}) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns/products',
      params,
    );
    if (result['success'] == true) {
      return List<Map<String, dynamic>>.from(result['data'] ?? []);
    }
    throw Exception(result['message'] ?? 'Failed to fetch return products');
  }

  /// Fetch lots for a product
  Future<List<Map<String, dynamic>>> getMtReturnProductLots(int productId) async {
    final result = await _post(
      '${AppConstants.apiPrefix}/mt/returns/products/$productId/lots',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return List<Map<String, dynamic>>.from(result['data'] ?? []);
    }
    throw Exception(result['message'] ?? 'Failed to fetch product lots');
  }
}

