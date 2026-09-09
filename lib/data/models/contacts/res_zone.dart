class ResZone {
  final int id;
  final String name;
  final String? code;
  final int? defaultWarehouseId;
  final String? defaultWarehouseName;
  final int? locationId;
  final String? locationName;

  const ResZone({
    required this.id,
    required this.name,
    this.code,
    this.defaultWarehouseId,
    this.defaultWarehouseName,
    this.locationId,
    this.locationName,
  });

  factory ResZone.fromMap(Map<String, dynamic> map) {
    return ResZone(
      id: map['id'] is int ? map['id'] as int : int.parse(map['id'].toString()),
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString(),
      defaultWarehouseId: map['default_warehouse_id'] != null
          ? (map['default_warehouse_id'] is int
              ? map['default_warehouse_id'] as int
              : int.tryParse(map['default_warehouse_id'].toString()))
          : null,
      defaultWarehouseName: map['default_warehouse_name']?.toString(),
      locationId: map['location_id'] != null
          ? (map['location_id'] is int
              ? map['location_id'] as int
              : int.tryParse(map['location_id'].toString()))
          : null,
      locationName: map['location_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (code != null) 'code': code,
      if (defaultWarehouseId != null) 'default_warehouse_id': defaultWarehouseId,
      if (defaultWarehouseName != null)
        'default_warehouse_name': defaultWarehouseName,
      if (locationId != null) 'location_id': locationId,
      if (locationName != null) 'location_name': locationName,
    };
  }
}
