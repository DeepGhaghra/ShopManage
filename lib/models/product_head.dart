class ProductHead {
  final int id;
  final String productName;
  final int productRate;
  final int? folderId;
  final DateTime timeAdded;
  final int shopId;

  final String? brandName;

  ProductHead({
    required this.id,
    required this.productName,
    required this.productRate,
    this.folderId,
    required this.timeAdded,
    required this.shopId,
    this.brandName,
  });

  factory ProductHead.fromJson(Map<String, dynamic> json) {
    final folder = json['folders'] as Map?;
    return ProductHead(
      id: json['id'] as int,
      productName: json['product_name'] as String,
      productRate: json['product_rate'] as int,
      folderId: json['folder_id'] as int?,
      timeAdded: DateTime.parse(json['time_added'] as String),
      shopId: json['shop_id'] as int,
      brandName: folder?['folder_name'] as String?,
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
