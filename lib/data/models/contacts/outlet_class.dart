class OutletClass {
  final int id;
  final String name;

  const OutletClass({
    required this.id,
    required this.name,
  });

  factory OutletClass.fromMap(Map<String, dynamic> map) {
    return OutletClass(
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
