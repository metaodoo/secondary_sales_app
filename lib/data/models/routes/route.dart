import 'package:secondary_sales/core/util/parse.dart';
class RouteModel {
  final int id;
  final String name;
  final String? code;
  final bool active;
  final int? distributorId;
  final String? distributorName;
  final List<RouteEmployee> employees;
  final List<RouteOutlet> outlets;
  final int outletCount;

  RouteModel({
    required this.id,
    required this.name,
    this.code,
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
      code: map['code'],
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

  RouteOutlet({
    required this.lineId,
    required this.id,
    required this.name,
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
  });

  factory RouteOutlet.fromMap(Map<String, dynamic> map) {
    return RouteOutlet(
      lineId: asInt(map['line_id'] ?? map['lineId']),
      id: asInt(map['id']),
      name: map['name'] ?? '',
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
    );
  }

}
