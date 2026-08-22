import 'package:flutter/material.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/return_scrap_summary.dart';

/// Owns the scrap-transfer flow (writing off damaged/expired stock).
class ScrapProvider with ChangeNotifier {
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

  Future<List<ReturnScrapSummary>> fetchScraps({
    int page = 1,
    int pageSize = 20,
    String state = 'all',
    String? search,
    String? type,
    String? returnReciptStatus,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getScraps(
        page: page,
        pageSize: pageSize,
        state: state,
        search: search,
        type: type,
        returnReciptStatus: returnReciptStatus,
      );
      final data = List<Map<String, dynamic>>.from(response['data'] ?? []);
      return data.map(ReturnScrapSummary.fromMap).toList();
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> prepareScrap({int? distributorId}) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.prepareScrap(distributorId: distributorId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>?> getScrapProducts({
    String? search,
    int? distributorId,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getScrapProducts(
        search: search,
        distributorId: distributorId,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getScrapProductLots(
    int productId, {
    int? distributorId,
  }) async {
    try {
      return await _apiService.getScrapProductLots(
        productId,
        distributorId: distributorId,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  Future<Map<String, dynamic>?> createScrapDelivery({
    required List<Map<String, dynamic>> lines,
    int? distributorId,
    String? type,
    String? damageType,
    String? attachmentBase64,
    String? attachmentFilename,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.createScrap(
        lines: lines,
        distributorId: distributorId,
        type: type,
        damageType: damageType,
        attachmentBase64: attachmentBase64,
        attachmentFilename: attachmentFilename,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getScrapDetails(
    int scrapId, {
    String? type,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getScrapDetails(scrapId, type: type);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> updateScrapDelivery(
    int scrapId, {
    required List<Map<String, dynamic>> lines,
    String? type,
    String? damageType,
    bool sendToSalesOperation = false,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.updateScrap(
        scrapId,
        lines: lines,
        type: type,
        damageType: damageType,
        sendToSalesOperation: sendToSalesOperation,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> executeScrapAction(
    int scrapId,
    String action, {
    String? type,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.scrapAction(scrapId, action, type: type);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }
}

