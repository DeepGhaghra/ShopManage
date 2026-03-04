class Pricelist {
  final int? id;
  final int productId;
  final int partyId;
  final int price;
  final DateTime? timeAdded;
  final DateTime? modifiedAt;
  final int shopId;

  Pricelist({
    this.id,
    required this.productId,
    required this.partyId,
    required this.price,
    this.timeAdded,
    this.modifiedAt,
    required this.shopId,
  });

  factory Pricelist.fromJson(Map<String, dynamic> json) {
    return Pricelist(
      id: json['id'] as int?,
      productId: json['product_id'] as int,
      partyId: json['party_id'] as int,
      price: json['price'] as int,
      timeAdded: json['time_added'] != null ? DateTime.parse(json['time_added'] as String) : null,
      modifiedAt: json['modified_at'] != null ? DateTime.parse(json['modified_at'] as String) : null,
      shopId: json['shop_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'party_id': partyId,
      'price': price,
      'shop_id': shopId,
    };
  }
}
