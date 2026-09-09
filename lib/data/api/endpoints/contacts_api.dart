// ignore_for_file: use_null_aware_elements
part of '../api_service.dart';

/// Contacts endpoints for the secondary sales API.
extension ContactsApi on ApiService {
  Future<List<DistributionHub>> getDistributionHubs({String? search}) async {
    final params = <String, dynamic>{
      'customer_type': 'distributor',
      'page_size': 100,
      'active': true,
    };
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }

    final result = await _post(AppConstants.contactsEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => DistributionHub.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load hubs');
  }

  Future<List<Map<String, dynamic>>> getOutlets({
    String? search,
    int? routeId,
    bool? assigned,
    String? sort,
  }) async {
    final params = <String, dynamic>{
      'customer_type': 'outlet',
      'page_size': 100,
      'active': true,
    };
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }
    if (routeId != null) {
      params['route_id'] = routeId;
    }
    if (assigned != null) {
      params['assigned'] = assigned;
    }
    if (sort != null && sort.isNotEmpty) {
      params['sort'] = sort;
    }

    final result = await _post(AppConstants.contactsEndpoint, params);
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load outlets');
  }

  Future<DistributionHub> getDistributionHub(int id) async {
    final result = await _post('${AppConstants.contactsEndpoint}/$id', {
      'customer_type': 'distributor',
    });
    if (result['success'] == true) {
      return DistributionHub.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to load distributor');
  }

  Future<DistributionHub> createDistributionHub({
    required String name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? vat,
    double? partnerLatitude,
    double? partnerLongitude,
  }) async {
    final params = <String, dynamic>{
      'name': name,
      'customer_type': 'distributor',
      if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (street != null && street.trim().isNotEmpty) 'street': street.trim(),
      if (street2 != null && street2.trim().isNotEmpty)
        'street2': street2.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (zip != null && zip.trim().isNotEmpty) 'zip': zip.trim(),
      if (vat != null && vat.trim().isNotEmpty) 'vat': vat.trim(),
      if (partnerLatitude != null) 'partner_latitude': partnerLatitude,
      if (partnerLongitude != null) 'partner_longitude': partnerLongitude,
    };

    final result = await _post(AppConstants.createContactEndpoint, params);
    if (result['success'] == true) {
      return DistributionHub.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create distributor');
  }

  Future<List<OutletClass>> getOutletClasses() async {
    final result = await _post('${AppConstants.apiPrefix}/contacts/outlet_classes', {});
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => OutletClass.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load outlet classes');
  }

  Future<List<OutletType>> getOutletTypes() async {
    final result = await _post('${AppConstants.apiPrefix}/contacts/outlet_types', {});
    if (result['success'] == true) {
      final List<dynamic> data = result['data'] ?? [];
      return data.map((json) => OutletType.fromMap(json)).toList();
    }
    throw Exception(result['message'] ?? 'Failed to load outlet types');
  }

  Future<Map<String, dynamic>> createOutlet({
    required String name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? vat,
    int? routeId,
    int? outletClassId,
    int? outletTypeId,
    String? businessType,
    double? partnerLatitude,
    double? partnerLongitude,
  }) async {
    final params = <String, dynamic>{
      'name': name,
      'customer_type': 'outlet',
      'business_type': businessType ?? 'gt',
      if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (street != null && street.trim().isNotEmpty) 'street': street.trim(),
      if (street2 != null && street2.trim().isNotEmpty)
        'street2': street2.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (zip != null && zip.trim().isNotEmpty) 'zip': zip.trim(),
      if (vat != null && vat.trim().isNotEmpty) 'vat': vat.trim(),
      if (routeId != null) 'route_id': routeId,
      if (outletClassId != null) 'outlet_class_id': outletClassId,
      if (outletTypeId != null) 'outlet_type_id': outletTypeId,
      if (partnerLatitude != null) 'partner_latitude': partnerLatitude,
      if (partnerLongitude != null) 'partner_longitude': partnerLongitude,
    };

    final result = await _post(AppConstants.createContactEndpoint, params);
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to create outlet');
  }

  Future<Map<String, dynamic>> updateOutlet(
    int id, {
    String? name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? vat,
    int? outletClassId,
    int? outletTypeId,
  }) async {
    final params = <String, dynamic>{
      'customer_type': 'outlet',
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (street != null && street.trim().isNotEmpty) 'street': street.trim(),
      if (street2 != null && street2.trim().isNotEmpty)
        'street2': street2.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (zip != null && zip.trim().isNotEmpty) 'zip': zip.trim(),
      if (vat != null && vat.trim().isNotEmpty) 'vat': vat.trim(),
      if (outletClassId != null) 'outlet_class_id': outletClassId,
      if (outletTypeId != null) 'outlet_type_id': outletTypeId,
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/contacts/$id/update',
      params,
    );
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update outlet');
  }

  Future<DistributionHub> updateDistributionHub(
    int id, {
    String? name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? vat,
  }) async {
    final params = <String, dynamic>{
      'customer_type': 'distributor',
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (street != null && street.trim().isNotEmpty) 'street': street.trim(),
      if (street2 != null && street2.trim().isNotEmpty)
        'street2': street2.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (zip != null && zip.trim().isNotEmpty) 'zip': zip.trim(),
      if (vat != null && vat.trim().isNotEmpty) 'vat': vat.trim(),
    };

    final result = await _post(
      '${AppConstants.apiPrefix}/contacts/$id/update',
      params,
    );
    if (result['success'] == true) {
      return DistributionHub.fromMap(result['data'] ?? <String, dynamic>{});
    }
    throw Exception(result['message'] ?? 'Failed to update distributor');
  }

  Future<bool> archiveOutlet(int id) async {
    final result = await _post('${AppConstants.apiPrefix}/contacts/$id/archive', {
      'customer_type': 'outlet',
    });
    if (result['success'] == true) {
      return true;
    }
    throw Exception(result['message'] ?? 'Failed to archive outlet');
  }
}
