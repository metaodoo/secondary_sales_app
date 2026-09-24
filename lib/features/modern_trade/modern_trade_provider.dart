import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_outlet.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/data/models/sales/product_category.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';

class ModernTradeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<MtOutlet> _outlets = [];
  List<ProductCategory> _categories = [];
  int _loadingCount = 0;
  String? _error;
  int? _checkedInOutletId;
  int? _currentVisitId;
  DateTime? _checkInTime;
  bool _requiresVisitReason = false;
  int? _lastEmployeeId;

  // GPS & Proximity State
  Position? _currentPosition;
  bool _sortByNearest = false;
  bool _isGpsRefreshing = false;

  List<MtOutlet> get outlets => _outlets;
  List<ProductCategory> get categories => _categories;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;
  int? get checkedInOutletId => _checkedInOutletId;
  int? get currentVisitId => _currentVisitId;
  DateTime? get checkInTime => _checkInTime;
  bool get requiresVisitReason => _requiresVisitReason;

  Position? get currentPosition => _currentPosition;
  bool get sortByNearest => _sortByNearest;
  bool get isGpsRefreshing => _isGpsRefreshing;

  void setSortByNearest(bool value) {
    if (_sortByNearest != value) {
      _sortByNearest = value;
      notifyListeners();
    }
  }

  void toggleSortByNearest() {
    _sortByNearest = !_sortByNearest;
    notifyListeners();
  }

  void updateLocation(Position position) {
    _currentPosition = position;
    notifyListeners();
  }

  Future<Position?> refreshGpsPosition({bool requireFresh = false}) async {
    _isGpsRefreshing = true;
    notifyListeners();
    try {
      final pos = await LocationService.getCurrentPosition(
        requireFresh: requireFresh,
        timeLimit: const Duration(seconds: 10),
      );
      _currentPosition = pos;
      return pos;
    } catch (e) {
      debugPrint('GPS refresh error in MT provider: $e');
      return null;
    } finally {
      _isGpsRefreshing = false;
      notifyListeners();
    }
  }

  List<MtOutlet> getSortedOutlets({String searchQuery = ''}) {
    final q = searchQuery.trim().toLowerCase();
    final list = _outlets.where((o) {
      if (q.isEmpty) return true;
      final name = o.name.toLowerCase();
      final code = (o.ssCode ?? '').toLowerCase();
      final street = (o.street ?? '').toLowerCase();
      return name.contains(q) || code.contains(q) || street.contains(q);
    }).toList();

    if (!_sortByNearest || _currentPosition == null) {
      final active = <MtOutlet>[];
      final rest = <MtOutlet>[];
      for (final o in list) {
        if (o.id == _checkedInOutletId || o.isActiveCheckedIn) {
          active.add(o);
        } else {
          rest.add(o);
        }
      }
      return [...active, ...rest];
    }

    final userLat = _currentPosition!.latitude;
    final userLng = _currentPosition!.longitude;

    final active = <MtOutlet>[];
    final withDistance = <MapEntry<MtOutlet, double>>[];
    final withoutCoords = <MtOutlet>[];

    for (final outlet in list) {
      if (outlet.id == _checkedInOutletId || outlet.isActiveCheckedIn) {
        active.add(outlet);
        continue;
      }
      final d = ProximityHelper.calculateDistance(
        userLat: userLat,
        userLng: userLng,
        outletLat: outlet.latitude,
        outletLng: outlet.longitude,
      );
      if (d != null) {
        withDistance.add(MapEntry(outlet, d));
      } else {
        withoutCoords.add(outlet);
      }
    }

    withDistance.sort((a, b) => a.value.compareTo(b.value));

    return [
      ...active,
      ...withDistance.map((e) => e.key),
      ...withoutCoords,
    ];
  }

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
      final res = await _apiService.getMtOutlets(employeeId: _lastEmployeeId);
      final list = (res['outlets'] as List? ?? []);
      _outlets = list.map((m) => MtOutlet.fromMap(m is Map<String, dynamic> ? m : Map<String, dynamic>.from(m))).toList();
      
      // Update local check-in state if any outlet is active
      final active = _outlets.where((o) => o.isActiveCheckedIn).firstOrNull;
      if (active != null) {
        _checkedInOutletId = active.id;
        if (active.activeVisitId != null) {
          _currentVisitId = active.activeVisitId;
        }
        if (active.activeCheckInTime != null) {
          _checkInTime = active.activeCheckInTime;
        }
      } else if (_checkedInOutletId == null) {
        _checkedInOutletId = null;
        _currentVisitId = null;
        _checkInTime = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await _apiService.getProductCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load categories in MT provider: $e');
    }
  }

  Future<bool> checkIn({
    required int outletId,
    String? justificationReason,
    Position? position,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final pos = position ?? await LocationService.getCurrentPosition(
        requireFresh: true,
        timeLimit: const Duration(seconds: 15),
      );

      // If off-schedule justification reason is provided, submit justification (which creates & links visit)
      if (justificationReason != null && justificationReason.trim().isNotEmpty) {
        final res = await _apiService.createMtJustification(
          outletId: outletId,
          reason: justificationReason.trim(),
          latitude: pos.latitude,
          longitude: pos.longitude,
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
          latitude: pos.latitude,
          longitude: pos.longitude,
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

  /// Automatically clears active check-in state if the backend closed the MT visit due to geofence breach.
  void handleAutoCheckOut(int outletId) {
    if (_checkedInOutletId == outletId) {
      _checkedInOutletId = null;
      _currentVisitId = null;
      _requiresVisitReason = false;
      _checkInTime = null;
      notifyListeners();
      fetchOutlets();
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
    String? search,
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
        search: search,
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

  Future<({bool hasOpening, bool hasClosing, bool isClosingConfirmed, List<MtStockAudit> audits})> checkTodayAudits(int outletId) async {
    try {
      final now = DateTime.now();
      final dateStr =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final res = await _apiService.getStockAudits(
        outletId: outletId,
        date: dateStr,
        pageSize: 50,
      );
      final hasOpening = res.audits.any((a) => a.type == 'opening_stock');
      final closingAudit = res.audits.where((a) => a.type == 'closing_stock').firstOrNull;
      final hasClosing = closingAudit != null;
      final isClosingConfirmed = closingAudit?.isConfirmed ?? false;
      return (
        hasOpening: hasOpening,
        hasClosing: hasClosing,
        isClosingConfirmed: isClosingConfirmed,
        audits: res.audits,
      );
    } catch (e) {
      debugPrint('Error checking today audits: $e');
      return (
        hasOpening: false,
        hasClosing: false,
        isClosingConfirmed: false,
        audits: <MtStockAudit>[],
      );
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

  Future<MtStockAudit?> resetStockAudit(int auditId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final audit = await _apiService.resetStockAudit(auditId);
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
    int? outletId,
    String? search,
    int? categoryId,
    int page = 1,
    int pageSize = 1000,
  }) async {
    try {
      return await _apiService.getStockAuditProducts(
        outletId: outletId,
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
    String? dateFrom,
    String? dateTo,
    String? search,
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
        dateFrom: dateFrom,
        dateTo: dateTo,
        search: search,
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
