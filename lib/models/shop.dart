class Shop {
  final int id; // existing PK is bigserial/int? Wait, existing schema says id format int8, bigserial.
  final String shopName;
  final String? shopShortName;
  final int? adminId;
  final DateTime createdAt;
  final String shopPrintName;

  Shop({
    required this.id,
    required this.shopName,
    this.shopShortName,
    this.adminId,
    required this.createdAt,
    required this.shopPrintName,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as int,
      shopName: json['shop_name'] as String,
      shopShortName: json['shop_short_name'] as String?,
      adminId: json['admin_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      shopPrintName: json['shop_print_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_name': shopName,
      'shop_short_name': shopShortName,
      'admin_id': adminId,
      'created_at': createdAt.toIso8601String(),
      'shop_print_name': shopPrintName,
    };
  }
}
