// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Access-control endpoints (screen/action RBAC). See ACCESS_CONTROL_PLAN.md.
///
/// Both are driven by the bearer token (no employee_id needed): the backend
/// derives the mobile user/group from the JWT.
extension AccessApi on ApiService {
  /// Fetches the current user's UI access allow-set for their group.
  /// Returns the same shape as the login `access` block.
  Future<AccessControl> getAccessPermissions() async {
    final result = await _post(AppConstants.accessPermissionsEndpoint, {});
    if (result['success'] == true) {
      final data = result['data'];
      return AccessControl.fromMap(
        data is Map ? data.cast<String, dynamic>() : const <String, dynamic>{},
      );
    }
    throw Exception(result['message'] ?? 'Failed to load access permissions');
  }

  /// Pushes the app's screen/action catalog to Odoo so admins can grant it.
  /// Server-gated to groups with `can_manage_access`. Returns the sync counts.
  Future<Map<String, dynamic>> syncAccessCatalog(
    List<AccessResource> resources, {
    String? appVersion,
  }) async {
    final result = await _post(AppConstants.accessCatalogSyncEndpoint, {
      if (appVersion != null) 'app_version': appVersion,
      'resources': resources.map((r) => r.toMap()).toList(),
    });
    if (result['success'] == true) {
      final data = result['data'];
      return data is Map
          ? data.cast<String, dynamic>()
          : <String, dynamic>{};
    }
    throw Exception(result['message'] ?? 'Failed to sync access catalog');
  }
}
