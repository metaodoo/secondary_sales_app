part of '../api_service.dart';

/// Landing-dashboard summary endpoint.
extension DashboardApi on ApiService {
  /// Fetches the role-aware landing summary (attendance, target rollup, today's
  /// route / team, approvals). The server derives the employee from the bearer
  /// token; `employee_id` is sent for parity with the rest of the API but is
  /// ignored server-side.
  ///
  /// Throws when the endpoint is unavailable (e.g. the backend has not shipped
  /// `/dashboard/summary` yet, or the device is offline). Callers treat that as
  /// a graceful "summary unavailable" state rather than an error to surface.
  Future<DashboardSummary> getDashboardSummary() async {
    final result = await _post(AppConstants.dashboardSummaryEndpoint, {
      'employee_id': _activeEmployeeId,
    });
    if (result['success'] == true) {
      return DashboardSummary.fromMap(asMap(result['data']));
    }
    throw Exception(result['message'] ?? 'Failed to load dashboard summary');
  }
}
