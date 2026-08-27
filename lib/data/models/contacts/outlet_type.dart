class OutletType {
  final int id;
  final String name;

  const OutletType({
    required this.id,
    required this.name,
  });

  factory OutletType.fromMap(Map<String, dynamic> map) {
    return OutletType(
      id: map['id'] is int ? map['id'] as int : int.parse(map['id'].toString()),
      name: map['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}
