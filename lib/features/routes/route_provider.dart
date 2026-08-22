import 'package:flutter/material.dart';
import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/data/models/routes/visit_reason.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/core/services/location_service.dart';

class RouteProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<RouteModel> _routes = [];
  List<VisitReason> _visitReasons = [];
  RouteModel? _activeRoute;
  int _loadingCount = 0;
  String? _error;

  int? _checkedInOutletId;
  int? _currentVisitId;
  DateTime? _checkInTime;
  final Set<int> _checkedOutOutletIds = {};
  int? _lastEmployeeId;

  List<RouteModel> get routes => _routes;
  List<VisitReason> get visitReasons => _visitReasons;
  RouteModel? get activeRoute => _activeRoute;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;

  int? get checkedInOutletId => _checkedInOutletId;
  int? get currentVisitId => _currentVisitId;
  DateTime? get checkInTime => _checkInTime;
  Set<int> get checkedOutOutletIds => _checkedOutOutletIds;

  Future<List<VisitReason>> fetchVisitReasons() async {
    try {
      _visitReasons = await _apiService.getVisitReasons();
      notifyListeners();
      return _visitReasons;
    } catch (e) {
      _error = e.toString();
      return _visitReasons;
    }
  }

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);

    if (employeeId != _lastEmployeeId) {
      _lastEmployeeId = employeeId;
      _checkedInOutletId = null;
      _currentVisitId = null;
      _checkInTime = null;
      _checkedOutOutletIds.clear();
      if (employeeId != null) {
        fetchTodayVisits(employeeId);
      }
    }
  }

  Future<void> fetchRoutes({int? distributorId, String? search}) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final list = await _apiService.getRoutes(
        distributorId: distributorId,
        search: search,
      );
      _routes = list.map((m) => RouteModel.fromMap(m)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<RouteModel?> fetchRouteDetail(int routeId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      if (_lastEmployeeId != null) {
        await fetchTodayVisits(_lastEmployeeId!);
      }
      final map = await _apiService.getRouteDetail(routeId);
      final detail = RouteModel.fromMap(map);
      _activeRoute = detail;
      // Also update in list if present
      final idx = _routes.indexWhere((r) => r.id == routeId);
      if (idx != -1) {
        _routes[idx] = detail;
      }
      return detail;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  void setActiveRoute(RouteModel? route) {
    _activeRoute = route;
    notifyListeners();
  }

  Future<RouteModel?> createRoute({
    required String name,
    int? distributorId,
    List<int>? employeeIds,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final map = await _apiService.createRoute(
        name: name,
        distributorId: distributorId,
        employeeIds: employeeIds,
      );
      final created = RouteModel.fromMap(map);
      _routes.insert(0, created);
      return created;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<RouteModel?> updateRoute(
    int routeId, {
    required String name,
    int? distributorId,
    List<int>? employeeIds,
    bool? active,
    List<Map<String, dynamic>>? outlets,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final map = await _apiService.updateRoute(
        routeId,
        name: name,
        distributorId: distributorId,
        employeeIds: employeeIds,
        active: active,
        outlets: outlets,
      );
      final updated = RouteModel.fromMap(map);

      final idx = _routes.indexWhere((r) => r.id == routeId);
      if (idx != -1) {
        _routes[idx] = updated;
      }
      if (_activeRoute?.id == routeId) {
        _activeRoute = updated;
      }
      return updated;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<RouteOutlet?> addOutletToRoute(
    int routeId, {
    int? outletId,
    String? name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? city,
    int? sequence,
    double? expectedVisitTime,
    double? partnerLatitude,
    double? partnerLongitude,
    String? outletOwnerName,
    String? image1920,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.addOutletToRoute(
        routeId,
        outletId: outletId,
        name: name,
        mobile: mobile,
        phone: phone,
        email: email,
        street: street,
        city: city,
        sequence: sequence,
        expectedVisitTime: expectedVisitTime,
        partnerLatitude: partnerLatitude,
        partnerLongitude: partnerLongitude,
        outletOwnerName: outletOwnerName,
        image1920: image1920,
      );

      final newOutlet = RouteOutlet.fromMap(result);

      // Refresh active route detail to keep UI correctly updated with full list
      await fetchRouteDetail(routeId);

      return newOutlet;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllOutlets({
    String? search,
    bool? assigned = false,
  }) async {
    try {
      return await _apiService.getOutlets(search: search, assigned: assigned);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<Map<String, dynamic>?> updateOutlet(
    int outletId, {
    String? name,
    String? mobile,
    String? email,
    String? street,
    String? city,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final updated = await _apiService.updateOutlet(
        outletId,
        name: name,
        mobile: mobile,
        email: email,
        street: street,
        city: city,
      );
      return updated;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<bool> removeOutletFromRoute(int routeId, int outletId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final success = await _apiService.removeOutletFromRoute(
        routeId,
        outletId,
      );
      if (success) {
        await fetchRouteDetail(routeId);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> checkIn(
    int employeeId,
    int outletId, {
    int? routeId,
    String? image1920,
    Position? position,
  }) async {
    if (_loadingCount > 0) return;
    _loadingCount++;
    _error = null;
    notifyListeners();
    try {
      // Geofenced action: require a fresh fix so a stale cached position from a
      // previous outlet can neither fail the geofence you are standing in nor
      // pass one you are nowhere near.
      final pos = position ??
          await LocationService.getCurrentPosition(
            requireFresh: true,
            timeLimit: const Duration(seconds: 15),
          );
      final res = await _apiService.createVisit(
        employeeId,
        outletId,
        routeId: routeId ?? _activeRoute?.id,
        image1920: image1920,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      _checkedInOutletId = outletId;
      _currentVisitId = res['id'];
      _requiresVisitReason = res['requires_visit_reason'] == true;
      _checkInTime = DateTime.now();
      _checkedOutOutletIds.remove(outletId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  /// Whether the open visit has produced no sale order, in which case the
  /// server requires a reason before it will accept the check-out.
  bool _requiresVisitReason = false;
  bool get requiresVisitReason => _requiresVisitReason;

  Future<void> checkOut({int? visitReasonId, String? reasonNotes, double? saleAmount}) async {
    if (_currentVisitId == null) return;
    if (_loadingCount > 0) return;
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
      if (_checkedInOutletId != null) {
        _checkedOutOutletIds.add(_checkedInOutletId!);
      }
      _checkedInOutletId = null;
      _currentVisitId = null;
      _requiresVisitReason = false;
      _checkInTime = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> fetchTodayVisits(int employeeId) async {
    try {
      final res = await _apiService.getTodayVisits(employeeId);
      final activeVisit = res['active_visit'];
      final checkedOutIds = List<int>.from(res['checked_out_outlet_ids'] ?? []);

      _checkedOutOutletIds.clear();
      _checkedOutOutletIds.addAll(checkedOutIds);

      if (activeVisit != null) {
        _checkedInOutletId = activeVisit['outlet_id'];
        _currentVisitId = activeVisit['id'];
        _requiresVisitReason = activeVisit['requires_visit_reason'] == true;
        final checkInStr = activeVisit['check_in_time'];
        if (checkInStr != null) {
          String parsedTimeStr = checkInStr;
          if (!parsedTimeStr.endsWith('Z') && !parsedTimeStr.contains('+')) {
            parsedTimeStr = '${parsedTimeStr.replaceAll(' ', 'T')}Z';
          }
          _checkInTime = DateTime.parse(parsedTimeStr).toLocal();
        }
      } else {
        _checkedInOutletId = null;
        _currentVisitId = null;
        _requiresVisitReason = false;
        _checkInTime = null;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
