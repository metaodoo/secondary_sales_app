// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Device endpoints for the secondary sales API.
extension DeviceApi on ApiService {
  Future<void> registerMobileDevice({
    required String fcmToken,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    final result = await _post(AppConstants.mobileDeviceRegisterEndpoint, {
      'fcm_token': fcmToken,
      'platform': platform,
      if (deviceName != null && deviceName.trim().isNotEmpty)
        'device_name': deviceName.trim(),
      if (appVersion != null && appVersion.trim().isNotEmpty)
        'app_version': appVersion.trim(),
    });
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to register device token');
    }
  }

  Future<void> unregisterMobileDevice(String fcmToken) async {
    final result = await _post(AppConstants.mobileDeviceUnregisterEndpoint, {
      'fcm_token': fcmToken,
    });
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to unregister device token');
    }
  }
}
