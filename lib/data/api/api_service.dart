// ignore_for_file: use_null_aware_elements
import 'package:secondary_sales/data/models/inventory/virtual_location.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/data/models/sales/sale_order_detail.dart';
import 'package:secondary_sales/data/models/sales/delivery_prepare.dart';
import 'package:secondary_sales/data/models/delivery_item.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/core/access/access_control.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/util/parse.dart';

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
    final separator = path.contains('?') ? '&' : '?';
    return Uri.parse(
      '${AppConstants.baseUrl}$path${separator}db=${AppConstants.dbName}',
    );
  }

  Future<Map<String, dynamic>> _post(
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
      debugPrint('Odoo POST $url');
      debugPrint('Odoo params: ${json.encode(params)}');
    }

    try {
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

      if (isExpiredError && !isRetry && onTokenExpired != null) {
        final newToken = await onTokenExpired!();
        if (newToken != null) {
          _accessToken = newToken;
          return _post(path, params, true);
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
            return _post(path, params, true);
          }
        }
        throw Exception(message.toString());
      }

      final result = decoded['result'];
      if (result is Map<String, dynamic>) {
        final isTokenExpired =
            result['success'] == false &&
            (result['message']?.toString().contains('token expired') == true ||
                result['message']?.toString().contains('Token expired') ==
                    true);

        if (isTokenExpired && !isRetry && onTokenExpired != null) {
          final newToken = await onTokenExpired!();
          if (newToken != null) {
            _accessToken = newToken;
            return _post(path, params, true);
          }
        }
        return result;
      }
      throw Exception('Odoo response did not include a result object.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Odoo request failed for $path: $e');
      }
      if (e.toString().contains('token expired') &&
          !isRetry &&
          onTokenExpired != null) {
        final newToken = await onTokenExpired!();
        if (newToken != null) {
          _accessToken = newToken;
          return _post(path, params, true);
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
