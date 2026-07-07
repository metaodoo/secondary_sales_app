import 'package:flutter/material.dart';
import 'package:secondary_sales/data/api/api_service.dart';
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
    String? search,
    String? state,
    int? distributorId,
    String? type,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiService.getReturns(
        search: search,
        state: state,
        distributorId: distributorId,
        type: type,
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

  Future<Map<String, dynamic>?> prepareReturn({int? distributorId}) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.prepareReturn(distributorId: distributorId);
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
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getReturnProducts(
        search: search,
        distributorId: distributorId,
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
  }) async {
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getReturnProductLots(
        productId,
        distributorId: distributorId,
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
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getReturnDetails(returnId, type: type);
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
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }
}
