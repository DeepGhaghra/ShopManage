class Location {
  final int id;
  final String name;
  final int shopId;

  Location({
    required this.id,
    required this.name,
    required this.shopId,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as int,
      name: json['name'] as String,
      shopId: json['shop_id'] as int,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'name': name,
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
