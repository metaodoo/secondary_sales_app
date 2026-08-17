import 'package:flutter/material.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/data/models/return_scrap_summary.dart';

/// Owns the return-delivery flow (distributor -> company returns).
class ReturnProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  int _loadingCount = 0;
  String? _error;

  bool get isLoading => _loadingCount > 0;
  String? get error => _error;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);
  }

  Future<List<ReturnScrapSummary>> fetchReturns({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? state,
    String? returnReciptStatus,
    int? distributorId,
    String? type,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiService.getReturns(
        page: page,
        pageSize: pageSize,
        search: search,
        state: state,
        returnReciptStatus: returnReciptStatus,
        distributorId: distributorId,
        type: type,
        endpoint: endpoint,
      );
      final data = List<Map<String, dynamic>>.from(res['data'] ?? []);
      return data.map(ReturnScrapSummary.fromMap).toList();
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> prepareReturn({
    int? distributorId,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.prepareReturn(distributorId: distributorId, endpoint: endpoint);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchReturnProducts({
    String? search,
    int? distributorId,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getReturnProducts(
        search: search,
        distributorId: distributorId,
        endpoint: endpoint,
      );
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchReturnProductLots(
    int productId, {
    int? distributorId,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getReturnProductLots(
        productId,
        distributorId: distributorId,
        endpoint: endpoint,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> createReturnDelivery({
    required List<Map<String, dynamic>> lines,
    int? distributorId,
    String? type,
    String? challanNumber,
    String? damageType,
    String? attachmentBase64,
    String? attachmentFilename,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.createReturn(
        lines: lines,
        distributorId: distributorId,
        type: type,
        challanNumber: challanNumber,
        damageType: damageType,
        attachmentBase64: attachmentBase64,
        attachmentFilename: attachmentFilename,
        endpoint: endpoint,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getReturnDetails(
    int returnId, {
    String? type,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getReturnDetails(returnId, type: type, endpoint: endpoint);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> updateReturnDelivery(
    int returnId, {
    required List<Map<String, dynamic>> lines,
    String? type,
    String? challanNumber,
    String? damageType,
    bool sendToSalesOperation = false,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.updateReturn(
        returnId,
        lines: lines,
        type: type,
        challanNumber: challanNumber,
        damageType: damageType,
        sendToSalesOperation: sendToSalesOperation,
        endpoint: endpoint,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> executeReturnAction(
    int returnId,
    String action, {
    String? type,
    String endpoint = AppConstants.returnsEndpoint,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.returnAction(returnId, action, type: type, endpoint: endpoint);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }
}

