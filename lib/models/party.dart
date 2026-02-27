class Party {
  final int id;
  final String partyName;
  final String? city;
  final String? mobile;
  final DateTime timeAdded;
  final int shopId;

  Party({
    required this.id,
    required this.partyName,
    this.city,
    this.mobile,
    required this.timeAdded,
    required this.shopId,
  });

  factory Party.fromJson(Map<String, dynamic> json) {
    return Party(
      id: json['id'] as int,
      partyName: json['partyname'] as String,
      city: json['city'] as String?,
      mobile: json['mobile'] as String?,
      timeAdded: DateTime.parse(json['time_added'] as String),
      shopId: json['shop_id'] as int,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'partyname': partyName,
      if (city != null) 'city': city,
      if (mobile != null) 'mobile': mobile,
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
