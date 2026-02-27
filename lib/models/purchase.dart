class Purchase {
  final int id;
  final String date; // E.g., "DD/MM/YYYY" or similar per old db
  final int? partyId;
  final int? designId;
  final int quantity;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int? shopId;

  Purchase({
    required this.id,
    required this.date,
    this.partyId,
    this.designId,
    required this.quantity,
    required this.createdAt,
    required this.modifiedAt,
    this.shopId,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as int,
      date: json['date'] as String,
      partyId: json['party_id'] as int?,
      designId: json['design_id'] as int?,
      quantity: json['quantity'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: DateTime.parse(json['modified_at'] as String),
      shopId: json['shop_id'] as int?,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'date': date,
      'party_id': partyId,
      'design_id': designId,
      'quantity': quantity,
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
