class SalesEntry {
  final int id;
  final DateTime date;
  final String invoiceno;
  final int partyId;
  final int productId; // Maps to product_head_id
  final int designId;   // Maps to products_design_id
  final int locationId; // Maps to location_id
  final int quantity;
  final int rate;
  final int amount;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int shopId;

  SalesEntry({
    required this.id,
    required this.date,
    required this.invoiceno,
    required this.partyId,
    required this.productId,
    required this.designId,
    required this.locationId,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.createdAt,
    required this.modifiedAt,
    required this.shopId,
  });

  factory SalesEntry.fromJson(Map<String, dynamic> json) {
    return SalesEntry(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      invoiceno: json['invoiceno'] as String,
      partyId: json['party_id'] as int,
      productId: json['product_id'] as int,
      designId: json['design_id'] as int,
      locationId: json['location_id'] as int? ?? 0, // Fallback for old data
      quantity: json['quantity'] as int,
      rate: json['rate'] as int,
      amount: json['amount'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: DateTime.parse(json['modified_at'] as String),
      shopId: json['shop_id'] as int,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}", // Format as YYYY-MM-DD
      'invoiceno': invoiceno,
      'party_id': partyId,
      'product_id': productId,
      'design_id': designId,
      'location_id': locationId,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
