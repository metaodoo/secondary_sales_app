// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Transfers endpoints for the secondary sales API.
extension TransfersApi on ApiService {
  Future<List<VirtualLocation>> getVirtualLocations({
    String? search,
    String? locationType,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page_size': 100,
    };
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (locationType != null && locationType.isNotEmpty) {
      params['location_type'] = locationType;
    }

    final result = await _post(AppConstants.virtualLocationsEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => VirtualLocation.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load virtual locations');
  }

  Future<VirtualLocation> getVirtualLocation(int locationId) async {
    final result = await _post(
      '${AppConstants.virtualLocationsEndpoint}/$locationId',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return VirtualLocation.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to load virtual location');
  }

  Future<VirtualLocation> createVirtualLocation({
    required String name,
    required int assignedEmployeeId,
    required int assignedDistributorId,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'name': name,
      'location_type': 'van_loading',
      'assigned_employee_id': assignedEmployeeId,
      'assigned_distributor_id': assignedDistributorId,
    };

    final result = await _post(
      AppConstants.createVirtualLocationEndpoint,
      params,
    );
    if (result['success'] == true) {
      return VirtualLocation.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create virtual location');
  }

  Future<VirtualTransferPrepare> prepareVirtualTransfer() async {
    final result = await _post(
      '${AppConstants.virtualTransfersEndpoint}/prepare',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return VirtualTransferPrepare.fromMap(
        result['data'] ?? <String, dynamic>{},
      );
    }
    throw Exception(result['message'] ?? 'Failed to prepare virtual transfer');
  }

  Future<List<TransferProduct>> getTransferProducts({
    required int destinationLocationId,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'destination_location_id': destinationLocationId,
      'page_size': 100,
    };
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }
    final result = await _post(
      '${AppConstants.virtualTransfersEndpoint}/products',
      params,
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => TransferProduct.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load transfer products');
  }

  Future<List<TransferLot>> getTransferProductLots(
    int productId, {
    required int destinationLocationId,
    String? vanOperationType,
  }) async {
    final result = await _post(
      '${AppConstants.virtualTransfersEndpoint}/products/$productId/lots',
      {
        'employee_id': _activeEmployeeId,
        'destination_location_id': destinationLocationId,
        if (vanOperationType != null) 'van_operation_type': vanOperationType,
      },
    );
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => TransferLot.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load transfer lots');
  }

  Future<VirtualTransfer> createVirtualTransfer({
    required int destinationLocationId,
    required List<VirtualTransferLineEntry> lines,
    String? vanOperationType,
  }) async {
    final payloadLines = <Map<String, dynamic>>[];
    for (final line in lines) {
      final payload = <String, dynamic>{
        'product_id': line.product.id,
        if (vanOperationType == 'unload') ...{
          'fresh_qty': line.freshQty ?? line.quantity,
          'scrap_qty': line.scrapQty ?? 0.0,
        } else ...{
          'quantity': line.quantity,
        }
      };

      if (line.product.requiresLots) {
        if (line.lotLines.isNotEmpty) {
          // Manual lot selection
          payload['lot_lines'] = line.lotLines
              .where((l) => l.lot != null && ((l.freshQty ?? l.quantity) > 0 || (l.scrapQty ?? 0) > 0))
              .map((l) => {
                    'lot_id': l.lot!.lotId,
                    if (vanOperationType == 'unload') ...{
                      'fresh_qty': l.freshQty ?? l.quantity,
                      'scrap_qty': l.scrapQty ?? 0.0,
                    } else ...{
                      'quantity': l.quantity,
                    }
                  })
              .toList();
        } else {
          // Auto-assign using FIFO
          payload['lot_lines'] = await _buildTransferLotPayload(
            line,
            destinationLocationId,
            vanOperationType: vanOperationType,
          );
        }
      }
      payloadLines.add(payload);
    }

    final reqPayload = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'destination_location_id': destinationLocationId,
      'lines': payloadLines,
    };
    if (vanOperationType != null) {
      reqPayload['van_operation_type'] = vanOperationType;
    }

    final result =
        await _post('${AppConstants.virtualTransfersEndpoint}/create', reqPayload);
    if (result['success'] == true) {
      return VirtualTransfer.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create virtual transfer');
  }

  Future<VirtualTransfer> updateVirtualTransfer(
    int transferId, {
    required int destinationLocationId,
    required List<VirtualTransferLineEntry> lines,
    String? vanOperationType,
  }) async {
    final payloadLines = <Map<String, dynamic>>[];
    for (final line in lines) {
      final payload = <String, dynamic>{
        'product_id': line.product.id,
        if (vanOperationType == 'unload') ...{
          'fresh_qty': line.freshQty ?? line.quantity,
          'scrap_qty': line.scrapQty ?? 0.0,
        } else ...{
          'quantity': line.quantity,
        }
      };

      if (line.product.requiresLots) {
        if (line.lotLines.isNotEmpty) {
          payload['lot_lines'] = line.lotLines
              .where((l) => l.lot != null && ((l.freshQty ?? l.quantity) > 0 || (l.scrapQty ?? 0) > 0))
              .map((l) => {
                    'lot_id': l.lot!.lotId,
                    if (vanOperationType == 'unload') ...{
                      'fresh_qty': l.freshQty ?? l.quantity,
                      'scrap_qty': l.scrapQty ?? 0.0,
                    } else ...{
                      'quantity': l.quantity,
                    }
                  })
              .toList();
        } else {
          payload['lot_lines'] = await _buildTransferLotPayload(
            line,
            destinationLocationId,
            vanOperationType: vanOperationType,
          );
        }
      }
      payloadLines.add(payload);
    }

    final reqPayload = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'destination_location_id': destinationLocationId,
      'lines': payloadLines,
    };
    if (vanOperationType != null) {
      reqPayload['van_operation_type'] = vanOperationType;
    }

    final result =
        await _post('${AppConstants.virtualTransfersEndpoint}/$transferId/update', reqPayload);
    if (result['success'] == true) {
      return VirtualTransfer.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update virtual transfer');
  }

  Future<List<Map<String, dynamic>>> getVanLoadingTargets({
    required int employeeId,
    required DateTime date,
    String? vanOperationType,
    int? destinationLocationId,
  }) async {
    final formattedDate =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    final params = <String, dynamic>{
      'employee_id': employeeId,
      'date': formattedDate,
      if (vanOperationType != null) 'van_operation_type': vanOperationType,
      if (destinationLocationId != null) 'destination_location_id': destinationLocationId,
    };
    
    final result = await _post('/api/v1/van_loading/targets', params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load van loading targets');
  }

  Future<List<VirtualTransfer>> getVirtualTransfers({
    String? search,
    String? state,
    String? vanOperationType,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, dynamic>{
      'employee_id': _activeEmployeeId,
      'page_size': 100,
    };
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }
    final selectedState = state?.trim();
    if (selectedState != null &&
        selectedState.isNotEmpty &&
        selectedState != 'all') {
      params['state'] = selectedState;
    }
    if (vanOperationType != null &&
        vanOperationType.isNotEmpty &&
        vanOperationType != 'all') {
      params['van_operation_type'] = vanOperationType;
    }
    if (dateFrom != null) {
      params['date'] =
          '${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    }
    // Note: The backend API currently only supports 'date' as a single day, but the UI date range usually means filtering between two dates.
    // If we need both from/to, the backend was set up for 'date' meaning scheduled_date on that specific day. 
    // We updated the backend to `date` = > & < in virtual_transfers.py but it only takes one date `date = payload.get("date")`. Wait, the backend only takes one date in virtual_transfers.py!
    // But in Sale Order List they might take dateFrom and dateTo. Let's just pass date_from and date_to so it doesn't break.
    if (dateFrom != null) {
      params['date_from'] =
          '${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    }
    if (dateTo != null) {
      params['date_to'] =
          '${dateTo.year.toString().padLeft(4, '0')}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
    }

    final result = await _post(AppConstants.virtualTransfersEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => VirtualTransfer.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load virtual transfers');
  }

  Future<VirtualTransfer> getVirtualTransfer(int transferId) async {
    final result = await _post(
      '${AppConstants.virtualTransfersEndpoint}/$transferId',
      {'employee_id': _activeEmployeeId},
    );
    if (result['success'] == true) {
      return VirtualTransfer.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to load virtual transfer');
  }

  Future<VirtualTransfer> validateVirtualTransfer(int transferId) async {
    final result = await _post(
      '${AppConstants.virtualTransfersEndpoint}/$transferId/action',
      {'employee_id': _activeEmployeeId, 'action': 'validate'},
    );
    if (result['success'] == true) {
      final data = result['data'];
      final transfer = data is Map ? data['transfer'] : null;
      return VirtualTransfer.fromMap(
        transfer is Map
            ? transfer.cast<String, dynamic>()
            : <String, dynamic>{},
      );
    }
    throw Exception(result['message'] ?? 'Failed to validate virtual transfer');
  }

  Future<VirtualTransfer> cancelVirtualTransfer(int transferId) async {
    final result = await _post(
      '${AppConstants.virtualTransfersEndpoint}/$transferId/action',
      {'employee_id': _activeEmployeeId, 'action': 'cancel'},
    );
    if (result['success'] == true) {
      return VirtualTransfer.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to cancel virtual transfer');
  }
}
