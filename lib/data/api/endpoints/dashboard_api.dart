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
  Future<DashboardSummary> getDashboardSummary({
    String preset = 'today',
    DateTime? dateFrom,
    DateTime? dateTo,
    int? scopeEmployeeId,
  }) async {
    final result = await _post(AppConstants.dashboardSummaryEndpoint, {
      'employee_id': _activeEmployeeId,
      'preset': preset,
      if (dateFrom != null)
        'date_from':
            '${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}',
      if (dateTo != null)
        'date_to':
            '${dateTo.year.toString().padLeft(4, '0')}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}',
      'scope_employee_id': ?scopeEmployeeId,
    });
    if (result['success'] == true) {
      return DashboardSummary.fromMap(asMap(result['data']));
    }
    throw Exception(result['message'] ?? 'Failed to load dashboard summary');
  }
}
