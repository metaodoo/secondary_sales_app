import 'package:secondary_sales/core/util/parse.dart';

class MtOutlet {
  const MtOutlet({
    required this.id,
    required this.name,
    this.ssCode,
    this.phone,
    this.street,
    this.latitude,
    this.longitude,
    this.isRecommended = false,
    this.isAllowed = true,
    this.isVisited = false,
    this.isActiveCheckedIn = false,
    this.justificationStatus,
    this.justificationRequestId,
    this.businessType,
  });

  final int id;
  final String name;
  final String? ssCode;
  final String? phone;
  final String? street;
  final double? latitude;
  final double? longitude;
  final bool isRecommended;
  final bool isAllowed;
  final bool isVisited;
  final bool isActiveCheckedIn;
  final String? justificationStatus;
  final int? justificationRequestId;
  final String? businessType;

  factory MtOutlet.fromMap(Map<String, dynamic> map) {
    return MtOutlet(
      id: asIntOrNull(map['id']) ?? 0,
      name: (map['name'] ?? '').toString(),
      ssCode: asNullableString(map['ss_code']),
      phone: asNullableString(map['phone']),
      street: asNullableString(map['street']),
      latitude: map['latitude'] == null || map['latitude'] == false ? null : asDouble(map['latitude']),
      longitude: map['longitude'] == null || map['longitude'] == false ? null : asDouble(map['longitude']),
      isRecommended: map['is_recommended'] == true,
      isAllowed: map['is_allowed'] != false,
      isVisited: map['is_visited'] == true,
      isActiveCheckedIn: map['is_active_checked_in'] == true,
      justificationStatus: asNullableString(map['justification_status']),
      justificationRequestId: asIntOrNull(map['justification_request_id']),
      businessType: asNullableString(map['business_type']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ss_code': ssCode,
    'phone': phone,
    'street': street,
    'latitude': latitude,
    'longitude': longitude,
    'is_recommended': isRecommended,
    'is_allowed': isAllowed,
    'is_visited': isVisited,
    'is_active_checked_in': isActiveCheckedIn,
    'justification_status': justificationStatus,
    'justification_request_id': justificationRequestId,
    'business_type': businessType,
  };
}
