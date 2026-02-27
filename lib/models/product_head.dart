class ProductHead {
  final int id;
  final String productName;
  final int productRate;
  final int? folderId;
  final DateTime timeAdded;
  final int shopId;

  ProductHead({
    required this.id,
    required this.productName,
    required this.productRate,
    this.folderId,
    required this.timeAdded,
    required this.shopId,
  });

  factory ProductHead.fromJson(Map<String, dynamic> json) {
    return ProductHead(
      id: json['id'] as int,
      productName: json['product_name'] as String,
      productRate: json['product_rate'] as int,
      folderId: json['folder_id'] as int?,
      timeAdded: DateTime.parse(json['time_added'] as String),
      shopId: json['shop_id'] as int,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'product_name': productName,
      'product_rate': productRate,
      'folder_id': folderId,
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
