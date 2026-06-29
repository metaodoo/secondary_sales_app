import 'package:flutter/material.dart';
import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/data/models/inventory/virtual_location.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';
import 'package:secondary_sales/data/api/api_service.dart';

/// Owns virtual locations, warehouses, transfer products/lots, virtual
/// transfers and the van-loading flow (which is built on virtual transfers).
class TransferProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<VirtualLocation> _virtualLocations = [];
  List<Warehouse> _warehouses = [];
  List<SalesEmployee> _employees = [];
  List<VirtualTransfer> _virtualTransfers = [];
  List<TransferProduct> _transferProducts = [];
  VirtualTransferPrepare? _transferPrepare;
  int _loadingCount = 0;
  String? _error;

  List<VirtualLocation> get virtualLocations => _virtualLocations;
  List<Warehouse> get warehouses => _warehouses;
  List<SalesEmployee> get employees => _employees;
  List<VirtualTransfer> get virtualTransfers => _virtualTransfers;
  List<TransferProduct> get transferProducts => _transferProducts;
  VirtualTransferPrepare? get transferPrepare => _transferPrepare;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);
  }

  Future<void> fetchVirtualLocations({
    String? search,
    String? locationType,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _virtualLocations = await _apiService.getVirtualLocations(
        search: search,
        locationType: locationType,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> fetchWarehouses() async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _warehouses = await _apiService.getWarehouses();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> fetchEmployees({int? distributorId, String? search}) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _employees = await _apiService.getEmployees(
        distributorId: distributorId,
        search: search,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  void clearEmployees({bool notify = true}) {
    _employees = [];
    if (notify) {
      notifyListeners();
    }
  }

  Future<VirtualLocation> getVirtualLocation(int locationId) {
    return _apiService.getVirtualLocation(locationId);
  }

  Future<VirtualLocation?> createVirtualLocation({
    required String name,
    required int assignedEmployeeId,
    required int assignedDistributorId,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final loc = await _apiService.createVirtualLocation(
        name: name,
        assignedEmployeeId: assignedEmployeeId,
        assignedDistributorId: assignedDistributorId,
      );
      _virtualLocations.insert(0, loc);
      return loc;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> prepareVirtualTransfer() async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _transferPrepare = await _apiService.prepareVirtualTransfer();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> searchTransferProducts({
    required int destinationLocationId,
    String? search,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _transferProducts = await _apiService.getTransferProducts(
        destinationLocationId: destinationLocationId,
        search: search,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getVanLoadingTargets({
    required int employeeId,
    required DateTime date,
    String? vanOperationType,
    int? destinationLocationId,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getVanLoadingTargets(
        employeeId: employeeId,
        date: date,
        vanOperationType: vanOperationType,
        destinationLocationId: destinationLocationId,
      );
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> fetchVirtualTransfers({
    String? search,
    String? state,
    String? vanOperationType,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _virtualTransfers = await _apiService.getVirtualTransfers(
        search: search,
        state: state,
        vanOperationType: vanOperationType,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<TransferLot>> fetchTransferLots(
    int productId, {
    required int destinationLocationId,
  }) async {
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getTransferProductLots(
        productId,
        destinationLocationId: destinationLocationId,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<VirtualTransfer?> createVirtualTransfer({
    required int destinationLocationId,
    required List<VirtualTransferLineEntry> lines,
    String? vanOperationType,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.createVirtualTransfer(
        destinationLocationId: destinationLocationId,
        lines: lines,
        vanOperationType: vanOperationType,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<VirtualTransfer?> updateVirtualTransfer(
    int transferId, {
    required int destinationLocationId,
    required List<VirtualTransferLineEntry> lines,
    String? vanOperationType,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.updateVirtualTransfer(
        transferId,
        destinationLocationId: destinationLocationId,
        lines: lines,
        vanOperationType: vanOperationType,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<VirtualTransfer> getVirtualTransfer(int transferId) {
    return _apiService.getVirtualTransfer(transferId);
  }

  Future<VirtualTransfer?> validateVirtualTransfer(int transferId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.validateVirtualTransfer(transferId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<VirtualTransfer?> cancelVirtualTransfer(int transferId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.cancelVirtualTransfer(transferId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }
}
