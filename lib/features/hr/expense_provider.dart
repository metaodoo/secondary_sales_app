import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class ExpenseProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  final AuthProvider _authProvider;

  bool _isLoadingCategories = false;
  bool _isLoadingDrafts = false;
  bool _isLoadingOwn = false;
  bool _isLoadingPending = false;
  bool _isLoadingDetails = false;
  bool _isActionLoading = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _myExpenses = [];
  List<Map<String, dynamic>> _pendingApprovals = [];
  Map<String, dynamic>? _selectedSheetDetails;

  String? _errorMessage;
  String? _actionError;
  String? _requestError;

  // Filter state
  String _activeTab = 'own'; // own, pending
  String? _stateFilter; // optional (draft, submit, approve, done, cancel)
  String? _searchQuery;
  String? _dateFrom;
  String? _dateTo;

  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingDrafts => _isLoadingDrafts;
  bool get isLoadingOwn => _isLoadingOwn;
  bool get isLoadingPending => _isLoadingPending;
  bool get isLoadingList => _activeTab == 'own' ? _isLoadingOwn : _isLoadingPending;
  bool get isLoadingDetails => _isLoadingDetails;
  bool get isActionLoading => _isActionLoading;
  bool get isSubmitting => _isSubmitting;

  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get drafts => _drafts;
  List<Map<String, dynamic>> get myExpenses => _myExpenses;
  List<Map<String, dynamic>> get pendingApprovals => _pendingApprovals;
  List<Map<String, dynamic>> get sheetsList => _activeTab == 'own' ? _myExpenses : _pendingApprovals;
  Map<String, dynamic>? get selectedSheetDetails => _selectedSheetDetails;

  String? get errorMessage => _errorMessage;
  String? get actionError => _actionError;
  String? get requestError => _requestError;
  String get activeTab => _activeTab;
  String? get stateFilter => _stateFilter;
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;
  String? get searchQuery => _searchQuery;

  ExpenseProvider(this._authProvider) {
    _apiService.updateAccessToken(_authProvider.accessToken);
    _apiService.updateSessionId(_authProvider.sessionId);
    _apiService.updateEmployeeId(_authProvider.employeeId);

    // Initial loads
    fetchCategories();
    fetchSheetList(tab: 'own');
    fetchSheetList(tab: 'pending');
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
    _stateFilter = null;
    notifyListeners();
    // Refresh the activated tab
    fetchSheetList(tab: tab);
  }

  void setStateFilter(String? state) {
    _stateFilter = state;
    notifyListeners();
    fetchSheetList(tab: _activeTab);
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDateRange(String? from, String? to) {
    _dateFrom = from;
    _dateTo = to;
    notifyListeners();
    // Refresh both tabs with the new date range filter
    fetchSheetList(tab: 'own');
    fetchSheetList(tab: 'pending');
  }

  Future<void> fetchCategories() async {
    _isLoadingCategories = true;
    notifyListeners();

    try {
      final response = await _apiService.getExpenseCategories();
      if (response['success'] == true) {
        final List data = response['data'] ?? [];
        _categories = data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch expense categories: $e');
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> fetchDrafts() async {
    if (_employeeId == 0) return;
    _isLoadingDrafts = true;
    notifyListeners();

    try {
      final response = await _apiService.getExpenseDrafts(_employeeId);
      if (response['success'] == true) {
        final List data = response['data'] ?? [];
        _drafts = data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch draft expenses: $e');
    } finally {
      _isLoadingDrafts = false;
      notifyListeners();
    }
  }

  Future<void> fetchSheetList({String? tab}) async {
    if (_employeeId == 0) return;
    final mode = tab ?? _activeTab;
    
    if (mode == 'own') {
      _isLoadingOwn = true;
    } else {
      _isLoadingPending = true;
    }
    notifyListeners();

    try {
      final response = await _apiService.getExpenseSheetList(
        employeeId: _employeeId,
        mode: mode,
        state: _stateFilter,
        startDate: _dateFrom,
        endDate: _dateTo,
      );

      if (response['success'] == true) {
        final List data = response['data'] ?? [];
        final mappedData = data.map((e) => e as Map<String, dynamic>).toList();
        if (mode == 'own') {
          _myExpenses = mappedData;
        } else {
          _pendingApprovals = mappedData;
        }
      } else {
        _errorMessage = response['message'];
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch expense reports: $e';
    } finally {
      if (mode == 'own') {
        _isLoadingOwn = false;
      } else {
        _isLoadingPending = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchSheetDetails(int sheetId) async {
    _isLoadingDetails = true;
    _selectedSheetDetails = null;
    notifyListeners();

    try {
      final response = await _apiService.getExpenseSheetDetails(sheetId);
      if (response['success'] == true) {
        _selectedSheetDetails = response['data'];
      } else {
        _errorMessage = response['message'];
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch details: $e';
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> createAndSubmitSheet({
    String? title,
    String? description,
    required List<Map<String, dynamic>> expenses,
    String? attachment,
    String? attachmentName,
  }) async {
    _apiService.updateAccessToken(_authProvider.accessToken);
    _apiService.updateSessionId(_authProvider.sessionId);
    _apiService.updateEmployeeId(_authProvider.employeeId);

    if (_employeeId == 0) {
      _requestError = 'Your user account is not linked to an active employee record.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _requestError = null;
    notifyListeners();

    try {
      final response = await _apiService.submitExpenseSheet(
        employeeId: _employeeId,
        title: title,
        description: description,
        expenses: expenses,
        attachment: attachment,
        attachmentName: attachmentName,
      );

      if (response['success'] == true) {
        await fetchSheetList(tab: 'own');
        return true;
      } else {
        _requestError = response['message'] ?? 'Failed to submit expense report.';
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

  Future<bool> approveSheet(int sheetId) async {
    _isActionLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final response = await _apiService.approveExpenseSheet(sheetId);
      if (response['success'] == true) {
        await fetchSheetList(tab: 'own');
        await fetchSheetList(tab: 'pending');
        if (_selectedSheetDetails != null && _selectedSheetDetails!['id'] == sheetId) {
          await fetchSheetDetails(sheetId);
        }
        return true;
      } else {
        _actionError = response['message'] ?? 'Failed to approve sheet.';
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

  Future<bool> refuseSheet(int sheetId, String reason) async {
    _isActionLoading = true;
    _actionError = null;
    notifyListeners();

    try {
      final response = await _apiService.refuseExpenseSheet(
        sheetId: sheetId,
        reason: reason,
      );
      if (response['success'] == true) {
        await fetchSheetList(tab: 'own');
        await fetchSheetList(tab: 'pending');
        if (_selectedSheetDetails != null && _selectedSheetDetails!['id'] == sheetId) {
          await fetchSheetDetails(sheetId);
        }
        return true;
      } else {
        _actionError = response['message'] ?? 'Failed to reject sheet.';
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
