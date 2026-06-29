import 'package:secondary_sales/core/util/parse.dart';
class SalesEmployee {
  final int id;
  final String name;
  final String? workPhone;
  final String? mobilePhone;
  final String? workEmail;
  final String? jobTitle;
  final Map<String, dynamic>? distributor;
  final List<dynamic>? assignedRoutes;

  SalesEmployee({
    required this.id,
    required this.name,
    this.workPhone,
    this.mobilePhone,
    this.workEmail,
    this.jobTitle,
    this.distributor,
    this.assignedRoutes,
  });

  factory SalesEmployee.fromMap(Map<String, dynamic> map) {
    return SalesEmployee(
      id: asInt(map['id']),
      name: map['name'] ?? '',
      workPhone: map['work_phone'],
      mobilePhone: map['mobile_phone'],
      workEmail: map['work_email'],
      jobTitle: map['job_title'],
      distributor: map['distributor'],
      assignedRoutes: map['assigned_routes'],
    );
  }

  String get subtitle {
    final parts = [
      mobilePhone,
      workPhone,
      jobTitle,
    ].where((part) => part != null && part.trim().isNotEmpty);
    final value = parts.join(' • ');
    return value.isEmpty ? 'Employee' : value;
  }

}
