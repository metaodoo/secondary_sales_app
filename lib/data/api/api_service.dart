// ignore_for_file: use_null_aware_elements
import 'package:secondary_sales/data/models/inventory/virtual_location.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:secondary_sales/core/services/offline_database_helper.dart';
import 'package:secondary_sales/core/services/offline_sync_engine.dart';
import 'package:http/http.dart' as http;
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/data/models/sales/product_category.dart';
import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/contacts/outlet_class.dart';
import 'package:secondary_sales/data/models/contacts/outlet_type.dart';
import 'package:secondary_sales/data/models/contacts/res_zone.dart';
import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/data/models/sales/sale_order_detail.dart';
import 'package:secondary_sales/data/models/sales/delivery_prepare.dart';
import 'package:secondary_sales/data/models/delivery_item.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/data/models/dashboard/dashboard_summary.dart';
import 'package:secondary_sales/data/models/notifications/app_notification.dart';
import 'package:secondary_sales/data/models/notifications/app_notice.dart';
import 'package:secondary_sales/data/models/notifications/notice_channel.dart';
import 'package:secondary_sales/data/models/routes/visit_reason.dart';
import 'package:secondary_sales/core/access/access_control.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';

part 'endpoints/device_api.dart';
part 'endpoints/contacts_api.dart';
part 'endpoints/employees_api.dart';
part 'endpoints/visits_api.dart';
part 'endpoints/routes_api.dart';
part 'endpoints/catalog_api.dart';
part 'endpoints/sales_api.dart';
part 'endpoints/deliveries_api.dart';
part 'endpoints/transfers_api.dart';
part 'endpoints/returns_api.dart';
part 'endpoints/scraps_api.dart';
part 'endpoints/attendance_api.dart';
part 'endpoints/leave_api.dart';
part 'endpoints/expense_api.dart';
part 'endpoints/access_api.dart';
part 'endpoints/my_team_api.dart';
part 'endpoints/location_api.dart';
part 'endpoints/dashboard_api.dart';
part 'endpoints/notification_api.dart';
part 'endpoints/notice_api.dart';
part 'endpoints/modern_trade_api.dart';

class ApiService {
  ApiService._internal();

  /// Single shared instance. All providers and screens use this so there is
  /// one http.Client and one source of truth for the auth token/session.
  static final ApiService instance = ApiService._internal();

  final http.Client _client = http.Client();
  String? _sessionId;
  String? _accessToken;
  int? _employeeId;

  static Future<String?> Function()? onTokenExpired;

  /// Why the server last rejected our credentials, from the `reason` the API
  /// sends alongside an `unauthorized` error.
  ///
  /// Set immediately before [onTokenExpired] fires, so that if the refresh also
  /// fails the auth layer can explain the sign-out ("an administrator signed
  /// you out") instead of dumping the user on the login screen with no reason.
  /// Cleared on a successful sign-in.
  static String? lastAuthFailureReason;

  /// Whether a response says our credentials are dead rather than our request
  /// being wrong.
  ///
  /// The backend used to tag a revoked session `validation_error`, so the app
  /// could only recognise the literal string `token expired` and a
  /// force-logged-out user stayed signed in, hitting an error snackbar on every
  /// screen. `unauthorized` is the code both the mobile API boundary and the
  /// auth controller's 401 now use. The old string stays in the test so this
  /// still behaves against a server that has not been upgraded.
  static bool _isAuthFailure(Map<String, dynamic> result) {
    if (result['success'] != false) return false;
    if (result['error'] == 'unauthorized') {
      final data = result['data'];
      lastAuthFailureReason =
          data is Map ? data['reason']?.toString() : null;
      return true;
    }
    final message = result['message']?.toString().toLowerCase() ?? '';
    return message.contains('token expired');
  }

  void updateSessionId(String? sessionId) {
    _sessionId = sessionId;
  }

  void updateEmployeeId(int? employeeId) {
    _employeeId = employeeId;
  }

  void updateAccessToken(String? accessToken) {
    _accessToken = accessToken;
  }

  int get _activeEmployeeId {
    if (_employeeId == null) {
      throw Exception('Authentication required: No active employee ID found.');
    }
    return _employeeId!;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Odoo-Database': AppConstants.dbName,
    'X-Odoo-Db': AppConstants.dbName,
    'X-Openerp-Database': AppConstants.dbName,
    if (_accessToken != null && _accessToken!.isNotEmpty)
      'Authorization': 'Bearer $_accessToken',
    if (_sessionId != null && _sessionId!.isNotEmpty)
      'Cookie': 'session_id=$_sessionId',
  };

  Uri _buildApiUri(String path) {
    // A blank db name means "let the server decide", not a missing setting:
    // single-database deployments (Odoo.sh) resolve the database from the
    // hostname and refuse to list databases at all, so there is nothing to send.
    final dbName = AppConstants.dbName;
    if (dbName.isEmpty) {
      return Uri.parse('${AppConstants.baseUrl}$path');
    }
    final separator = path.contains('?') ? '&' : '?';
    return Uri.parse('${AppConstants.baseUrl}$path${separator}db=$dbName');
  }

  /// Direct raw POST call bypassing offline interception (used by OfflineSyncEngine).
  Future<Map<String, dynamic>> executeRawPost(
    String path,
    Map<String, dynamic> params, [
    bool isRetry = false,
  ]) async {
    final url = _buildApiUri(path);
    final body = json.encode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params,
      'id': DateTime.now().millisecondsSinceEpoch,
    });

    if (kDebugMode) {
      debugPrint('Odoo Raw POST $url');
      debugPrint('Odoo params: ${json.encode(params)}');
    }

    final response = await _client
        .post(url, headers: _headers, body: body)
        .timeout(const Duration(seconds: 20));

    if (kDebugMode) {
      debugPrint('Odoo response ${response.statusCode}: ${response.body}');
    }

    final isExpiredError =
        response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.body.contains('token expired');

    if (isExpiredError) {
      try {
        final decodedBody = json.decode(response.body);
        if (decodedBody is Map && decodedBody['reason'] != null) {
          lastAuthFailureReason = decodedBody['reason'].toString();
        }
      } catch (_) {}
    }

    if (isExpiredError && !isRetry && onTokenExpired != null) {
      final newToken = await onTokenExpired!();
      if (newToken != null) {
        _accessToken = newToken;
        return executeRawPost(path, params, true);
      }
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid JSON-RPC response.');
    }

    if (decoded.containsKey('error')) {
      final error = decoded['error'];
      String message = 'Odoo Server Error';
      if (error is Map) {
        final dataMsg = error['data']?['message'];
        final errMsg = error['message'];
        if (dataMsg != null && dataMsg.toString().trim().isNotEmpty) {
          message = dataMsg.toString();
        } else if (errMsg != null && errMsg.toString().trim().isNotEmpty) {
          message = errMsg.toString();
        }
      }

      if (message.toString().contains('token expired') &&
          !isRetry &&
          onTokenExpired != null) {
        final newToken = await onTokenExpired!();
        if (newToken != null) {
          _accessToken = newToken;
          return executeRawPost(path, params, true);
        }
      }
      throw Exception(message.toString());
    }

    final result = decoded['result'];
    if (result is Map<String, dynamic>) {
      final isTokenExpired = _isAuthFailure(result);
      if (isTokenExpired && !isRetry && onTokenExpired != null) {
        final newToken = await onTokenExpired!();
        if (newToken != null) {
          _accessToken = newToken;
          return executeRawPost(path, params, true);
        }
      }
      return result;
    }
    throw Exception('Odoo response did not include a result object.');
  }

  bool _isWriteEndpoint(String path) {
    return path.contains('/visits/create') ||
        (path.contains('/visits/') && path.contains('/update')) ||
        path.contains('/sale-orders/create') ||
        path.contains('/returns') ||
        path.contains('/qc_returns') ||
        path.contains('/scraps') ||
        path.contains('/hr/attendance/action') ||
        path.contains('/hr/expense/sheet/create') ||
        path.contains('/contacts/create') ||
        path.contains('/ss/routes/create');
  }

  String _resolveEntityType(String path) {
    if (path.contains('/visits/create')) return 'visit';
    if (path.contains('/visits/') && path.contains('/update')) return 'visit_update';
    if (path.contains('/sale-orders/create')) return 'order';
    if (path.contains('/returns') || path.contains('/qc_returns')) return 'return';
    if (path.contains('/scraps')) return 'scrap';
    if (path.contains('/hr/attendance/action')) return 'attendance';
    if (path.contains('/hr/expense/sheet/create')) return 'expense';
    if (path.contains('/contacts/create')) return 'outlet';
    return 'generic_write';
  }

  Future<Map<String, dynamic>> _synthesizeOfflineSuccessResponse(
    String path,
    Map<String, dynamic> params,
    String entityType,
  ) async {
    // Pre-flight sanity validation: block empty orders before polluting outbox
    if (entityType == 'order') {
      final lines = params['order_lines'] as List?;
      if (lines == null || lines.isEmpty) {
        throw Exception('Cannot submit order: At least one product item is required.');
      }
    }

    String? parentUuid = params['visit_uuid']?.toString() ?? params['parent_uuid']?.toString();
    if (parentUuid == null && (entityType == 'order' || entityType == 'return')) {
      // Auto-link to currently active offline visit
      parentUuid = await OfflineDatabaseHelper.instance.getActiveVisitUuid();
    }

    final clientUuid = params['client_uuid']?.toString();
    final opUuid = await OfflineDatabaseHelper.instance.enqueueOperation(
      entityType: entityType,
      endpoint: path,
      payload: params,
      parentUuid: parentUuid,
      clientUuid: clientUuid,
    );

    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    Map<String, dynamic> data = {
      'id': nowEpoch ~/ 1000,
      'client_uuid': opUuid,
      'name': 'OFFLINE-$nowEpoch',
      'state': 'draft',
    };

    if (entityType == 'visit') {
      data['state'] = 'in_progress';
      data['outlet_id'] = params['outlet_id'];
      data['check_in_time'] = params['check_in_time'] ?? nowIso;
      data['visit_type'] = params['visit_type'] ?? 'standard';
    } else if (entityType == 'visit_update') {
      data['state'] = 'completed';
      data['check_out_time'] = params['check_out_time'] ?? nowIso;
    } else if (entityType == 'order') {
      data['client_order_uuid'] = opUuid;
      data['outlet_id'] = params['outlet_id'] ?? 0;
      data['order_lines'] = params['order_lines'] ?? [];
      data['amount_total'] = 0.0;
    } else if (entityType == 'attendance') {
      data['action'] = params['action'] ?? 'check_in';
      data['timestamp'] = nowIso;
    }

    return {
      'success': true,
      'offline': true,
      'message': 'Operation queued offline for background sync.',
      'data': data,
      'result': data,
    };
  }

  bool _isCacheableReadEndpoint(String path) {
    if (_isWriteEndpoint(path)) return false;
    return path.contains('/ss/routes') ||
        (path.contains('/contacts') && !path.contains('/create')) ||
        (path.contains('/products') && !path.contains('/create')) ||
        path.contains('/visit-reasons') ||
        path.contains('/warehouses') ||
        path.contains('/transfer-lots');
  }

  String _resolveCacheKey(String path, Map<String, dynamic> params) {
    if (path.contains('/ss/routes')) return 'routes_${params['employee_id'] ?? _employeeId ?? 0}';
    if (path.contains('/contacts')) return 'contacts_route_${params['route_id'] ?? 'all'}';
    if (path.contains('/products/categories')) return 'catalog_categories';
    if (path.contains('/products')) return 'catalog_products';
    if (path.contains('/visit-reasons')) return 'visit_reasons';
    if (path.contains('/warehouses')) return 'warehouses';
    if (path.contains('/transfer-lots')) return 'transfer_lots_${params['product_id'] ?? 0}';
    return 'cache_${path.replaceAll('/', '_')}';
  }

  String _resolveCacheType(String path) {
    if (path.contains('/ss/routes')) return 'routes';
    if (path.contains('/contacts')) return 'contacts';
    if (path.contains('/products')) return 'products';
    if (path.contains('/visit-reasons')) return 'reasons';
    if (path.contains('/warehouses')) return 'warehouses';
    if (path.contains('/transfer-lots')) return 'lots';
    return 'master';
  }

  void _cacheMasterData(String path, Map<String, dynamic> params, Map<String, dynamic> result) {
    if (result['success'] != true) return;
    final cacheKey = _resolveCacheKey(path, params);
    final cacheType = _resolveCacheType(path);
    final dataToCache = result['data'] ?? result['reasons'] ?? result['routes'] ?? result;

    OfflineDatabaseHelper.instance.saveMasterData(
      entityKey: cacheKey,
      entityType: cacheType,
      data: dataToCache,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> params, [
    bool isRetry = false,
  ]) async {
    final isWrite = _isWriteEndpoint(path);
    final isCacheableRead = _isCacheableReadEndpoint(path);
    final entityType = isWrite ? _resolveEntityType(path) : null;

    if (entityType == 'order') {
      final existingUuid = params['client_order_uuid']?.toString() ?? params['client_uuid']?.toString();
      final orderUuid = (existingUuid != null && existingUuid.isNotEmpty)
          ? existingUuid
          : const Uuid().v4();
      params['client_order_uuid'] = orderUuid;
      params['client_uuid'] = orderUuid;
    }

    // Fast-path: If known to be offline, bypass 20s network timeout immediately
    if (!OfflineSyncEngine.instance.isOnline) {
      if (isWrite) {
        debugPrint('[ApiService] Immediate offline buffer for write: $path');
        return _synthesizeOfflineSuccessResponse(
          path,
          params,
          _resolveEntityType(path),
        );
      }
      if (isCacheableRead) {
        final cached = await OfflineDatabaseHelper.instance.getMasterData(
          _resolveCacheKey(path, params),
        );
        if (cached != null) {
          debugPrint('[ApiService] Immediate offline cache hit: $path');
          return {
            'success': true,
            'offline': true,
            'data': cached,
            'reasons': cached,
          };
        }
      }
    }

    try {
      final result = await executeRawPost(path, params, isRetry);

      // Async cache master data for reads
      if (isCacheableRead) {
        _cacheMasterData(path, params, result);
      }

      return result;
    } catch (e) {
      final isConnError = e is SocketException ||
          e is TimeoutException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('timeout') ||
          e.toString().contains('502') ||
          e.toString().contains('503') ||
          e.toString().contains('504');

      if (isConnError) {
        // Fallback for writes: Save to SQLite outbox
        if (isWrite) {
          debugPrint('[ApiService] Network failed during write, buffering offline: $path');
          return _synthesizeOfflineSuccessResponse(
            path,
            params,
            _resolveEntityType(path),
          );
        }

        // Fallback for reads: Load from SQLite master cache
        if (isCacheableRead) {
          final cached = await OfflineDatabaseHelper.instance.getMasterData(
            _resolveCacheKey(path, params),
          );
          if (cached != null) {
            debugPrint('[ApiService] Network failed during read, returning cached data: $path');
            return {
              'success': true,
              'offline': true,
              'data': cached,
              'reasons': cached,
            };
          }
        }
      }

      if (e is TimeoutException) {
        throw Exception(
          'The server took too long to respond. Please check your internet connection and try again.',
        );
      } else if (e is SocketException) {
        throw Exception(
          'No internet connection. Please check your network and try again.',
        );
      }
      final errStr = e.toString();
      if (errStr.startsWith('Exception: ')) {
        throw Exception(errStr.substring(11));
      }
      throw Exception(errStr);
    }
  }

  /// Resolves which lots to draw from for a lot-tracked line, allocating the
  /// requested quantity FIFO across the available lots. Returns typed
  /// [TransferLotInput]s so the caller (the provider) can resolve lots as an
  /// explicit step *before* creating a transfer — rather than this network
  /// call being hidden inside the create/serialize path. Throws with a
  /// product-specific message when there isn't enough lot quantity.
  Future<List<TransferLotInput>> resolveTransferLotInputs(
    VirtualTransferLineEntry line, {
    required int destinationLocationId,
    String? vanOperationType,
  }) async {
    final lots = await getTransferProductLots(
      line.product.id,
      destinationLocationId: destinationLocationId,
      vanOperationType: vanOperationType,
    );

    if (vanOperationType == 'unload') {
      final inputs = <TransferLotInput>[];
      var freshRemaining = line.freshQty ?? line.quantity;
      var scrapRemaining = line.scrapQty ?? 0.0;

      for (final lot in lots) {
        if (freshRemaining <= 0 && scrapRemaining <= 0) break;

        double allocatedFresh = 0.0;
        double allocatedScrap = 0.0;

        if (freshRemaining > 0 && lot.availableQty > 0) {
          allocatedFresh = lot.availableQty >= freshRemaining ? freshRemaining : lot.availableQty;
          freshRemaining -= allocatedFresh;
        }

        if (scrapRemaining > 0 && lot.scrapQty > 0) {
          allocatedScrap = lot.scrapQty >= scrapRemaining ? scrapRemaining : lot.scrapQty;
          scrapRemaining -= allocatedScrap;
        }

        if (allocatedFresh > 0 || allocatedScrap > 0) {
          inputs.add(TransferLotInput(
            lot: lot,
            freshQty: allocatedFresh,
            scrapQty: allocatedScrap,
          ));
        }
      }

      if (freshRemaining > 0.000001) {
        throw Exception(
          'Not enough fresh lot quantity available for ${line.product.name}',
        );
      }
      if (scrapRemaining > 0.000001) {
        throw Exception(
          'Not enough scrap lot quantity available for ${line.product.name}',
        );
      }

      return inputs;
    } else {
      var remaining = line.quantity;
      final inputs = <TransferLotInput>[];

      for (final lot in lots) {
        if (remaining <= 0) break;
        final quantity = lot.availableQty >= remaining
            ? remaining
            : lot.availableQty;
        if (quantity <= 0) continue;
        inputs.add(TransferLotInput(lot: lot, quantity: quantity));
        remaining -= quantity;
      }

      if (remaining > 0.000001) {
        throw Exception(
          'Not enough lot quantity available for ${line.product.name}',
        );
      }

      return inputs;
    }
  }

  // ---------------------------------------------------------------------------
  // ROUTE VISITS
  // ---------------------------------------------------------------------------

}
