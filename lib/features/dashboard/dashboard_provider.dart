import 'package:flutter/foundation.dart';

import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/dashboard/dashboard_summary.dart';

/// Backs the landing dashboard. Fetches the role-aware `/dashboard/summary`
/// snapshot and degrades gracefully: if the endpoint is unavailable (backend
/// not yet upgraded, or offline) it holds a null summary and flags
/// [summaryUnavailable] so the screen shows attendance + module navigation only,
/// with no error surfaced to the user.
class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  DashboardSummary? _summary;
  bool _isLoading = false;
  bool _summaryUnavailable = false;

  DashboardSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  /// True when the last fetch could not produce a summary (endpoint missing or
  /// unreachable). Used to hide KPI sections rather than show an error.
  bool get summaryUnavailable => _summaryUnavailable;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);
  }

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();

    try {
      _summary = await _apiService.getDashboardSummary();
      _summaryUnavailable = false;
    } catch (e) {
      // Non-fatal: the dashboard still works from attendance + modules alone.
      _summary = null;
      _summaryUnavailable = true;
      if (kDebugMode) {
        debugPrint('Dashboard summary unavailable: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData({bool notify = true}) {
    _summary = null;
    _isLoading = false;
    _summaryUnavailable = false;
    if (notify) notifyListeners();
  }
}
