import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class LeaveProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  final AuthProvider _authProvider;

  bool _isLoadingTypes = false;
  bool _isLoadingList = false;
  bool _isActionLoading = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _leaveTypes = [];
  List<Map<String, dynamic>> _leaveList = [];
  String? _errorMessage;
  String? _actionError;
  String? _requestError;

  // Filter state
  String _activeTab = 'own'; // own, pending, approved, rejected, all
  String? _searchQuery;
  String? _dateFrom;
  String? _dateTo;

  bool get isLoadingTypes => _isLoadingTypes;
  bool get isLoadingList => _isLoadingList;
  bool get isActionLoading => _isActionLoading;
  bool get isSubmitting => _isSubmitting;
  
  List<Map<String, dynamic>> get leaveTypes => _leaveTypes;
  List<Map<String, dynamic>> get leaveList => _leaveList;
  String? get errorMessage => _errorMessage;
  String? get actionError => _actionError;
  String? get requestError => _requestError;
  String get activeTab => _activeTab;
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;
  String? get searchQuery => _searchQuery;

  LeaveProvider(this._authProvider) {
    _apiService.updateAccessToken(_authProvider.accessToken);
    _apiService.updateSessionId(_authProvider.sessionId);
    _apiService.updateEmployeeId(_authProvider.employeeId);
    
    // Initial loads
    fetchLeaveTypes();
    fetchLeaveList();
  }

  int get _employeeId => _authProvider.user?.employeeId ?? 0;

  void clearError() {
    _errorMessage = null;
    _actionError = null;
    _requestError = null;
    notifyListeners();
  }

  void setActiveTab(String tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
    fetchLeaveList();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
    // In a real app, you might want to debounce this call
    fetchLeaveList();
  }

  void setDateRange(String? from, String? to) {
    _dateFrom = from;
    _dateTo = to;
    notifyListeners();
    fetchLeaveList();
  }

  Future<void> fetchLeaveTypes() async {
    if (_employeeId == 0) return;
    _isLoadingTypes = true;
    notifyListeners();

    try {
      final response = await _apiService.getLeaveTypes(_employeeId);
      if (response['success'] == true) {
        final List data = response['data'] ?? [];
        _leaveTypes = data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch leave types: $e');
    } finally {
      _isLoadingTypes = false;
      notifyListeners();
    }
  }

  Future<void> fetchLeaveList() async {
    if (_employeeId == 0) return;
    _isLoadingList = true;
    notifyListeners();

    try {
      final response = await _apiService.getLeaveList(
        employeeId: _employeeId,
        tabFilter: _activeTab,
        searchQuery: _searchQuery,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      if (response['success'] == true) {
        final List data = response['data'] ?? [];
        _leaveList = data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        _errorMessage = response['message'];
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch leaves: $e';
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  /// Fetches a single leave by id, for deep-linking from a notification where
  /// the list may not be loaded or may not contain that record. Returns null
  /// when the fetch fails or the caller is not allowed to see it.
  Future<Map<String, dynamic>?> fetchLeaveById(int leaveId) async {
    if (_employeeId == 0) return null;

    try {
      final response = await _apiService.getLeaveDetails(
        employeeId: _employeeId,
        leaveId: leaveId,
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
        return null;
      }
      _errorMessage = response['message'];
    } catch (e) {
      _errorMessage = 'Failed to fetch leave: $e';
    }

    notifyListeners();
    return null;
  }

  Future<bool> submitLeaveRequest({
    required int leaveTypeId,
    required String dateFrom,
    required String dateTo,
    required String reason,
    String? attachment,
    String? attachmentName,
  }) async {
    if (_employeeId == 0) return false;
    _isSubmitting = true;
    _errorMessage = null;
    _requestError = null;
    notifyListeners();

    try {
      final response = await _apiService.submitLeaveRequest(
        employeeId: _employeeId,
        leaveTypeId: leaveTypeId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        reason: reason,
        attachment: attachment,
        attachmentName: attachmentName,
      );

      if (response['success'] == true) {
        // Refresh the list after a successful request
        await fetchLeaveList();
        await fetchLeaveTypes(); // refresh balances
        return true;
      } else {
        _requestError = response['message'] ?? 'Failed to submit request.';
        return false;
      }
    } catch (e) {
      _requestError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitLeaveAction(int leaveId, String action) async {
    if (_employeeId == 0) return false;
    _isActionLoading = true;
    _errorMessage = null;
    _actionError = null;
    notifyListeners();

    try {
      final response = await _apiService.submitLeaveAction(
        employeeId: _employeeId,
        leaveId: leaveId,
        action: action,
      );

      if (response['success'] == true) {
        // Find the leave in the list and update its status
        final index = _leaveList.indexWhere((l) => l['leave_id'] == leaveId);
        if (index != -1) {
          _leaveList[index]['status'] = response['new_status'];
          _leaveList[index]['can_approve'] = false; // it is no longer pending
          notifyListeners();
        }
        return true;
      } else {
        _actionError = response['message'] ?? 'Failed to $action leave.';
        return false;
      }
    } catch (e) {
      _actionError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }
}
