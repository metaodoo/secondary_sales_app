import 'package:flutter/material.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_outlet.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/core/services/location_service.dart';

class ModernTradeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<MtOutlet> _outlets = [];
  int _loadingCount = 0;
  String? _error;
  int? _checkedInOutletId;
  int? _currentVisitId;
  DateTime? _checkInTime;
  bool _requiresVisitReason = false;
  int? _lastEmployeeId;

  List<MtOutlet> get outlets => _outlets;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;
  int? get checkedInOutletId => _checkedInOutletId;
  int? get currentVisitId => _currentVisitId;
  DateTime? get checkInTime => _checkInTime;
  bool get requiresVisitReason => _requiresVisitReason;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);

    if (employeeId != _lastEmployeeId) {
      _lastEmployeeId = employeeId;
      _checkedInOutletId = null;
      _currentVisitId = null;
      _requiresVisitReason = false;
      _checkInTime = null;
      _outlets.clear();
      if (employeeId != null) {
        fetchOutlets();
      }
    }
  }

  Future<void> fetchOutlets() async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiService.getMtOutlets();
      final list = (res['outlets'] as List? ?? []);
      _outlets = list.map((m) => MtOutlet.fromMap(m is Map<String, dynamic> ? m : Map<String, dynamic>.from(m))).toList();
      
      // Update local check-in state if any outlet is active
      final active = _outlets.where((o) => o.isActiveCheckedIn).firstOrNull;
      if (active != null) {
        _checkedInOutletId = active.id;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<bool> checkIn({
    required int outletId,
    String? justificationReason,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final position = await LocationService.getCurrentPosition(
        requireFresh: true,
        timeLimit: const Duration(seconds: 15),
      );

      // If off-schedule justification reason is provided, submit justification (which creates & links visit)
      if (justificationReason != null && justificationReason.trim().isNotEmpty) {
        final res = await _apiService.createMtJustification(
          outletId: outletId,
          reason: justificationReason.trim(),
          latitude: position.latitude,
          longitude: position.longitude,
        );
        final visit = res['visit'] is Map ? res['visit'] : null;
        _checkedInOutletId = outletId;
        _currentVisitId = visit != null ? visit['id'] : res['visit_id'];
        _requiresVisitReason = visit != null ? (visit['requires_visit_reason'] == true) : true;
        _checkInTime = DateTime.now();
      } else {
        // Recommended check-in via visit endpoint
        final visitRes = await _apiService.createVisit(
          _lastEmployeeId!,
          outletId,
          businessType: 'mt',
          visitType: 'standard',
          latitude: position.latitude,
          longitude: position.longitude,
        );

        _checkedInOutletId = outletId;
        _currentVisitId = visitRes['id'];
        _requiresVisitReason = visitRes['requires_visit_reason'] == true;
        _checkInTime = DateTime.now();
      }

      await fetchOutlets();
      return true;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> checkOut({
    int? visitReasonId,
    String? reasonNotes,
    double? saleAmount,
  }) async {
    if (_currentVisitId == null) return;
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      await _apiService.updateVisit(
        _currentVisitId!,
        checkOutTime: DateTime.now().toUtc().toIso8601String(),
        visitReasonId: visitReasonId,
        reasonNotes: reasonNotes,
        saleAmount: saleAmount,
      );
      _checkedInOutletId = null;
      _currentVisitId = null;
      _requiresVisitReason = false;
      _checkInTime = null;
      await fetchOutlets();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  // ─── Modern Trade Stock Audits ──────────────────────────────────────────
  List<MtStockAudit> _stockAudits = [];
  int _stockAuditsTotal = 0;
  List<MtSecSaleOrder> _secSaleOrders = [];
  int _secSaleOrdersTotal = 0;

  List<MtStockAudit> get stockAudits => _stockAudits;
  int get stockAuditsTotal => _stockAuditsTotal;
  List<MtSecSaleOrder> get secSaleOrders => _secSaleOrders;
  int get secSaleOrdersTotal => _secSaleOrdersTotal;

  Future<void> fetchStockAudits({
    int page = 1,
    int pageSize = 20,
    int? outletId,
    String? type,
    String? state,
    String? date,
    String? dateFrom,
    String? dateTo,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiService.getStockAudits(
        page: page,
        pageSize: pageSize,
        outletId: outletId,
        type: type,
        state: state,
        date: date,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (page == 1) {
        _stockAudits = res.audits;
      } else {
        _stockAudits.addAll(res.audits);
      }
      _stockAuditsTotal = res.total;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<MtStockAudit?> fetchStockAuditDetail(int auditId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getStockAuditDetail(auditId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<MtStockAudit?> createStockAudit({
    required int outletId,
    required String type,
    required List<Map<String, dynamic>> lines,
    int? visitId,
    String? notes,
    bool confirm = false,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final audit = await _apiService.createStockAudit(
        outletId: outletId,
        type: type,
        lines: lines,
        visitId: visitId,
        notes: notes,
        confirm: confirm,
      );
      return audit;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<MtStockAudit?> updateStockAudit({
    required int auditId,
    required int outletId,
    required String type,
    required List<Map<String, dynamic>> lines,
    int? visitId,
    String? notes,
    bool confirm = false,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final audit = await _apiService.updateStockAudit(
        auditId: auditId,
        outletId: outletId,
        type: type,
        lines: lines,
        visitId: visitId,
        notes: notes,
        confirm: confirm,
      );
      return audit;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<MtStockAudit?> confirmStockAudit(int auditId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final audit = await _apiService.confirmStockAudit(auditId);
      return audit;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<MtStockAuditProduct>> fetchAuditProducts({
    String? search,
    int? categoryId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      return await _apiService.getStockAuditProducts(
        search: search,
        categoryId: categoryId,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<void> fetchMtSecondarySales({
    int page = 1,
    int pageSize = 20,
    int? outletId,
    String? date,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiService.getMtSecondarySales(
        page: page,
        pageSize: pageSize,
        outletId: outletId,
        date: date,
      );
      if (page == 1) {
        _secSaleOrders = res.orders;
      } else {
        _secSaleOrders.addAll(res.orders);
      }
      _secSaleOrdersTotal = res.total;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<MtSecSaleOrder?> fetchMtSecondarySaleDetail(int orderId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getMtSecondarySaleDetail(orderId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }
}
