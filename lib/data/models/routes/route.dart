import 'package:secondary_sales/core/util/parse.dart';
class RouteModel {
  final int id;
  final String name;
  final bool active;
  final int? distributorId;
  final String? distributorName;
  final List<RouteEmployee> employees;
  final List<RouteOutlet> outlets;
  final int outletCount;

  RouteModel({
    required this.id,
    required this.name,
    required this.active,
    this.distributorId,
    this.distributorName,
    required this.employees,
    required this.outlets,
    required this.outletCount,
  });

  factory RouteModel.fromMap(Map<String, dynamic> map) {
    final dist = map['distributor'];
    final emps = map['employees'] as List? ?? [];
    final outs = map['outlets'] as List? ?? [];

    return RouteModel(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      active: map['active'] != false,
      distributorId: dist != null ? asInt(dist['id']) : null,
      distributorName: dist != null ? dist['name'] : null,
      employees: emps
          .map((e) => RouteEmployee.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      outlets: outs
          .map((o) => RouteOutlet.fromMap(Map<String, dynamic>.from(o)))
          .toList(),
      outletCount: asInt(map['outlet_count'] ?? map['outletCount']),
    );
  }

}

class RouteEmployee {
  final int id;
  final String name;
  final String? workPhone;
  final String? workEmail;

  RouteEmployee({
    required this.id,
    required this.name,
    this.workPhone,
    this.workEmail,
  });

  factory RouteEmployee.fromMap(Map<String, dynamic> map) {
    return RouteEmployee(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      workPhone: map['work_phone'],
      workEmail: map['work_email'],
    );
  }

}

class RouteOutlet {
  final int lineId;
  final int id;
  final String name;
  final String? code;
  final String? ownerName;
  final int sequence;
  final double expectedVisitTime;
  final String? phone;
  final String? mobile;
  final String? email;
  final String? street;
  final String? street2;
  final String? city;
  final String? zip;
  final String? vat;
  final bool active;
  final double? partnerLatitude;
  final double? partnerLongitude;
  final double? outletRadius;
  final int? outletClassId;
  final String? outletClassName;
  final int? outletTypeId;
  final String? outletTypeName;

  RouteOutlet({
    required this.lineId,
    required this.id,
    required this.name,
    this.code,
    this.ownerName,
    required this.sequence,
    required this.expectedVisitTime,
    this.phone,
    this.mobile,
    this.email,
    this.street,
    this.street2,
    this.city,
    this.zip,
    this.vat,
    required this.active,
    this.partnerLatitude,
    this.partnerLongitude,
    this.outletRadius,
    this.outletClassId,
    this.outletClassName,
    this.outletTypeId,
    this.outletTypeName,
  });

  String get displayNameWithCode {
    if (code != null && code!.trim().isNotEmpty) {
      return '$name (${code!.trim()})';
    }
    return name;
  }

  factory RouteOutlet.fromMap(Map<String, dynamic> map) {
    final rawClass = map['outlet_class'];
    final rawType = map['outlet_type'];

    return RouteOutlet(
      lineId: asInt(map['line_id'] ?? map['lineId']),
      id: asInt(map['id']),
      name: map['name'] ?? '',
      code: map['code'] ?? map['ss_code'],
      ownerName: map['owner_name'] ?? map['ownerName'],
      sequence: asInt(map['sequence']),
      expectedVisitTime: asDouble(
        map['expected_visit_time'] ?? map['expectedVisitTime'],
      ),
      phone: map['phone'],
      mobile: map['mobile'],
      email: map['email'],
      street: map['street'],
      street2: map['street2'],
      city: map['city'],
      zip: map['zip'],
      vat: map['vat'],
      active: map['active'] != false,
      partnerLatitude: map['partner_latitude'] != null ? asDouble(map['partner_latitude']) : null,
      partnerLongitude: map['partner_longitude'] != null ? asDouble(map['partner_longitude']) : null,
      outletRadius: map['outlet_radius'] != null ? asDouble(map['outlet_radius']) : null,
      outletClassId: map['outlet_class_id'] != null
          ? asInt(map['outlet_class_id'])
          : (rawClass is Map ? asInt(rawClass['id']) : null),
      outletClassName: rawClass is Map ? rawClass['name']?.toString() : null,
      outletTypeId: map['outlet_type_id'] != null
          ? asInt(map['outlet_type_id'])
          : (rawType is Map ? asInt(rawType['id']) : null),
      outletTypeName: rawType is Map ? rawType['name']?.toString() : null,
    );
  }

}
