import 'package:flutter/material.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';

class MtReturnProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;

  List<MtReturnRequest> _returns = [];
  MtReturnRequest? _selectedReturn;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isActionLoading = false;
  String? _errorMessage;
  int _totalReturns = 0;
  int _currentPage = 1;
  static const int _pageSize = 20;

  String _selectedStateFilter = 'all';
  String _selectedBucketFilter = 'all';
  String _searchQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  Map<String, dynamic>? _prepareData;
  List<Map<String, dynamic>> _availableProducts = [];
  List<Map<String, dynamic>> _availableLots = [];
  bool _isLoadingProducts = false;
  bool _isLoadingLots = false;

  // Getters
  List<MtReturnRequest> get returns => _returns;
  MtReturnRequest? get selectedReturn => _selectedReturn;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;
  int get totalReturns => _totalReturns;
  int get currentPage => _currentPage;
  bool get hasMore => _returns.length < _totalReturns;

  String get selectedStateFilter => _selectedStateFilter;
  String get selectedBucketFilter => _selectedBucketFilter;
  String get searchQuery => _searchQuery;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;

  Map<String, dynamic>? get prepareData => _prepareData;
  List<Map<String, dynamic>> get availableProducts => _availableProducts;
  List<Map<String, dynamic>> get availableLots => _availableLots;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingLots => _isLoadingLots;

  void setStateFilter(String state, {String? returnBucket}) {
    _selectedStateFilter = state;
    fetchReturns(returnBucket: returnBucket, refresh: true);
  }

  void setSearchQuery(String query, {String? returnBucket}) {
    _searchQuery = query;
    fetchReturns(returnBucket: returnBucket, refresh: true);
  }

  void setDateRange(DateTime? from, DateTime? to, {String? returnBucket}) {
    _dateFrom = from;
    _dateTo = to;
    fetchReturns(returnBucket: returnBucket, refresh: true);
  }

  void setBucketFilter(String bucket, {bool refresh = true}) {
    _selectedBucketFilter = bucket;
    if (refresh) {
      fetchReturns(returnBucket: bucket == 'all' ? null : bucket, refresh: true);
    }
  }

  Future<void> fetchReturns({String? returnBucket, bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final bucketToFetch = returnBucket ?? (_selectedBucketFilter != 'all' ? _selectedBucketFilter : null);

    try {
      final res = await _api.getMtReturns(
        page: _currentPage,
        pageSize: _pageSize,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        state: _selectedStateFilter != 'all' ? _selectedStateFilter : null,
        returnBucket: bucketToFetch,
        dateFrom: _dateFrom != null ? "${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}" : null,
        dateTo: _dateTo != null ? "${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}" : null,
      );

      if (refresh) {
        _returns = res.returns;
      } else {
        _returns.addAll(res.returns);
      }
      _totalReturns = res.total;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({String? returnBucket}) async {
    if (_isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    _currentPage++;
    notifyListeners();
    await fetchReturns(returnBucket: returnBucket, refresh: false);
  }

  Future<void> fetchReturnDetail(int returnId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedReturn = await _api.getMtReturnDetail(returnId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPrepareContext({int? partnerId}) async {
    try {
      _prepareData = await _api.prepareMtReturn(partnerId: partnerId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> fetchReturnProducts({String? search}) async {
    _isLoadingProducts = true;
    notifyListeners();

    try {
      _availableProducts = await _api.getMtReturnProducts(search: search);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> fetchProductLots(int productId) async {
    _isLoadingLots = true;
    _availableLots = [];
    notifyListeners();

    try {
      _availableLots = await _api.getMtReturnProductLots(productId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingLots = false;
      notifyListeners();
    }
  }

  Future<MtReturnRequest?> createReturn({
    required int partnerId,
    required String returnBucket,
    String? date,
    bool autoSubmit = false,
    required List<Map<String, dynamic>> lines,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.createMtReturn(
        partnerId: partnerId,
        returnBucket: returnBucket,
        date: date,
        autoSubmit: autoSubmit,
        lines: lines,
      );
      _selectedReturn = res;
      await fetchReturns(returnBucket: returnBucket, refresh: true);
      return res;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateReturnLines(int returnId, List<Map<String, dynamic>> lines) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateMtReturn(returnId, lines: lines);
      _selectedReturn = updated;
      final idx = _returns.indexWhere((r) => r.id == returnId);
      if (idx != -1) {
        _returns[idx] = updated;
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> executeAction(int returnId, String action, {List<Map<String, dynamic>>? lines}) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _api.executeMtReturnAction(returnId, action: action, lines: lines);
      _selectedReturn = updated;
      final idx = _returns.indexWhere((r) => r.id == returnId);
      if (idx != -1) {
        _returns[idx] = updated;
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }
}
