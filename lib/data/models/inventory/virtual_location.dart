class VirtualLocation {
  final int id;
  final String name;
  final String usage;
  final String? locationType;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? distributor;

  VirtualLocation({
    required this.id,
    required this.name,
    required this.usage,
    this.locationType,
    this.employee,
    this.distributor,
  });

  factory VirtualLocation.fromMap(Map<String, dynamic> map) {
    return VirtualLocation(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      usage: map['usage'] ?? '',
      locationType: map['location_type'],
      employee: map['employee'],
      distributor: map['distributor'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'usage': usage,
      'location_type': locationType,
      'employee': employee,
      'distributor': distributor,
    };
  }
}
