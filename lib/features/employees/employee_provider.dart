import 'package:flutter/material.dart';
import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/data/api/api_service.dart';

class EmployeeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<SalesEmployee> _employees = [];
  int _loadingCount = 0;
  String? _error;

  List<SalesEmployee> get employees => _employees;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);
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

  Future<SalesEmployee?> createEmployee({
    required String name,
    String? email,
    String? phone,
    String? workPhone,
    String? jobTitle,
    required int distributorId,
    List<int>? assignedRouteIds,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final emp = await _apiService.createEmployee(
        name: name,
        email: email,
        phone: phone,
        workPhone: workPhone,
        jobTitle: jobTitle,
        distributorId: distributorId,
        assignedRouteIds: assignedRouteIds,
      );
      _employees.insert(0, emp);
      return emp;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<SalesEmployee?> updateEmployee(
    int employeeId, {
    String? name,
    String? email,
    String? phone,
    String? workPhone,
    String? jobTitle,
    int? distributorId,
    List<int>? assignedRouteIds,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final emp = await _apiService.updateEmployee(
        employeeId,
        name: name,
        email: email,
        phone: phone,
        workPhone: workPhone,
        jobTitle: jobTitle,
        distributorId: distributorId,
        assignedRouteIds: assignedRouteIds,
      );
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = emp;
      }
      return emp;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<SalesEmployee?> getEmployeeDetail(int employeeId) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getEmployee(employeeId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchRoutes({int? distributorId}) async {
    _loadingCount++;
    _error = null;
    notifyListeners();
    try {
      return await _apiService.getRoutes(distributorId: distributorId);
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }
}
