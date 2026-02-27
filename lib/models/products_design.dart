class ProductsDesign {
  final int id;
  final String designNo;
  final int productHeadId;
  final DateTime timeAdded;
  final int shopId;

  ProductsDesign({
    required this.id,
    required this.designNo,
    required this.productHeadId,
    required this.timeAdded,
    required this.shopId,
  });

  factory ProductsDesign.fromJson(Map<String, dynamic> json) {
    return ProductsDesign(
      id: json['id'] as int,
      designNo: json['design_no'] as String,
      productHeadId: json['product_head_id'] as int,
      timeAdded: DateTime.parse(json['time_added'] as String),
      shopId: json['shop_id'] as int,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'design_no': designNo,
      'product_head_id': productHeadId,
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
