import 'package:flutter/material.dart';
import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/data/models/routes/visit_reason.dart';
import 'package:secondary_sales/data/models/contacts/outlet_class.dart';
import 'package:secondary_sales/data/models/contacts/outlet_type.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';

class RouteProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<RouteModel> _routes = [];
  List<VisitReason> _visitReasons = [];
  List<OutletClass> _outletClasses = [];
  List<OutletType> _outletTypes = [];
  RouteModel? _activeRoute;
  int _loadingCount = 0;
  String? _error;

  int? _checkedInOutletId;
  int? _currentVisitId;
  DateTime? _checkInTime;
  final Set<int> _checkedOutOutletIds = {};
  int? _lastEmployeeId;

  // GPS & Proximity State
  Position? _currentPosition;
  bool _sortByNearest = false;
  bool _isGpsRefreshing = false;

  List<RouteModel> get routes => _routes;
  List<VisitReason> get visitReasons => _visitReasons;
  List<OutletClass> get outletClasses => _outletClasses;
  List<OutletType> get outletTypes => _outletTypes;
  RouteModel? get activeRoute => _activeRoute;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;

  int? get checkedInOutletId => _checkedInOutletId;
  int? get currentVisitId => _currentVisitId;
  DateTime? get checkInTime => _checkInTime;
  Set<int> get checkedOutOutletIds => _checkedOutOutletIds;

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
      debugPrint('GPS refresh error in RouteProvider: $e');
      return null;
    } finally {
      _isGpsRefreshing = false;
      notifyListeners();
    }
  }

  List<RouteOutlet> getSortedRouteOutlets(
    List<RouteOutlet> outlets, {
    String searchQuery = '',
  }) {
    final q = searchQuery.trim().toLowerCase();
    final list = outlets.where((o) {
      if (q.isEmpty) return true;
      final name = o.name.toLowerCase();
      final code = (o.code ?? '').toLowerCase();
      final owner = (o.ownerName ?? '').toLowerCase();
      final phone = (o.phone ?? o.mobile ?? '').toLowerCase();
      final street = (o.street ?? '').toLowerCase();
      return name.contains(q) ||
          code.contains(q) ||
          owner.contains(q) ||
          phone.contains(q) ||
          street.contains(q);
    }).toList();

    if (!_sortByNearest || _currentPosition == null) {
      final active = <RouteOutlet>[];
      final rest = <RouteOutlet>[];
      for (final o in list) {
        if (o.id == _checkedInOutletId) {
          active.add(o);
        } else {
          rest.add(o);
        }
      }
      return [...active, ...rest];
    }

    final userLat = _currentPosition!.latitude;
    final userLng = _currentPosition!.longitude;

    final active = <RouteOutlet>[];
    final withDistance = <MapEntry<RouteOutlet, double>>[];
    final withoutCoords = <RouteOutlet>[];

    for (final outlet in list) {
      if (outlet.id == _checkedInOutletId) {
        active.add(outlet);
        continue;
      }
      final d = ProximityHelper.calculateDistance(
        userLat: userLat,
        userLng: userLng,
        outletLat: outlet.partnerLatitude,
        outletLng: outlet.partnerLongitude,
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

  Future<List<OutletClass>> fetchOutletClasses() async {
    try {
      _outletClasses = await _apiService.getOutletClasses();
      notifyListeners();
      return _outletClasses;
    } catch (e) {
      _error = e.toString();
      return _outletClasses;
    }
  }

  Future<List<OutletType>> fetchOutletTypes() async {
    try {
      _outletTypes = await _apiService.getOutletTypes();
      notifyListeners();
      return _outletTypes;
    } catch (e) {
      _error = e.toString();
      return _outletTypes;
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
    int? outletClassId,
    int? outletTypeId,
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
        outletClassId: outletClassId,
        outletTypeId: outletTypeId,
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
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      return await _apiService.getOutlets(
        search: search,
        assigned: assigned,
        page: page,
        pageSize: pageSize,
      );
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
    int? outletClassId,
    int? outletTypeId,
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
        outletClassId: outletClassId,
        outletTypeId: outletTypeId,
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

  Future<bool> archiveOutlet(int outletId, {int? activeRouteId}) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final success = await _apiService.archiveOutlet(outletId);
      if (success) {
        if (_activeRoute != null) {
          final updatedOutlets =
              _activeRoute!.outlets.where((o) => o.id != outletId).toList();
          final newCount =
              _activeRoute!.outletCount > 0 ? _activeRoute!.outletCount - 1 : 0;
          _activeRoute = RouteModel(
            id: _activeRoute!.id,
            name: _activeRoute!.name,
            active: _activeRoute!.active,
            distributorId: _activeRoute!.distributorId,
            distributorName: _activeRoute!.distributorName,
            employees: _activeRoute!.employees,
            outlets: updatedOutlets,
            outletCount: newCount,
          );
        }
        final routeIdToFetch = activeRouteId ?? _activeRoute?.id;
        if (routeIdToFetch != null) {
          await fetchRouteDetail(routeIdToFetch);
        }
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
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
      } else if (_checkedInOutletId != null && _checkedOutOutletIds.contains(_checkedInOutletId)) {
        _checkedInOutletId = null;
        _currentVisitId = null;
        _requiresVisitReason = false;
        _checkInTime = null;
      } else if (_checkedInOutletId == null) {
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

  /// Automatically clears active check-in state if the backend closed the visit due to geofence breach.
  void handleAutoCheckOut(int outletId) {
    if (_checkedInOutletId == outletId) {
      _checkedOutOutletIds.add(outletId);
      _checkedInOutletId = null;
      _currentVisitId = null;
      _requiresVisitReason = false;
      _checkInTime = null;
      notifyListeners();
    }
  }
}

