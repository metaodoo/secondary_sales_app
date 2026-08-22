import 'package:secondary_sales/core/util/parse.dart';
class DistributionHub {
  final int id;
  final String name;
  final String? code;
  final String? address;
  final String? street;
  final String? street2;
  final String? city;
  final String? zip;
  final String? phone;
  final String? mobile;
  final String? email;
  final String? vat;

  DistributionHub({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.street,
    this.street2,
    this.city,
    this.zip,
    this.phone,
    this.mobile,
    this.email,
    this.vat,
  });

  String get displayNameWithCode {
    if (code != null && code!.toString().trim().isNotEmpty) {
      return '$name (${code!.trim()})';
    }
    return name;
  }

  factory DistributionHub.fromMap(Map<String, dynamic> map) {
    return DistributionHub(
      id: asInt(map['id']),
      name: map['display_name'] ?? map['name'] ?? '',
      code: map['code'] ?? map['ss_code'],
      address: _buildAddress(map),
      street: map['street'],
      street2: map['street2'],
      city: map['city'],
      zip: map['zip'],
      phone: map['phone'],
      mobile: map['mobile'] ?? map['phone'],
      email: map['email'],
      vat: map['vat'],
    );
  }

  static String? _buildAddress(Map<String, dynamic> map) {
    final parts = [
      map['street'],
      map['street2'],
      map['city'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty);
    final address = parts.join(', ');
    return address.isEmpty ? null : address;
  }
}
