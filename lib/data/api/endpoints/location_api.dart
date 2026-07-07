// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

extension LocationApi on ApiService {
  Future<Map<String, dynamic>> syncEmployeeLocations({
    required List<Map<String, dynamic>> locations,
  }) async {
    return _post('/api/v1/employee/location/sync', {
      'locations': locations,
    });
  }
}
