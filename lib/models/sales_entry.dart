import '../utils/date_utils.dart';

class SalesEntry {
  final int id;
  final DateTime date;
  final String invoiceno;
  final int partyId;
  final String? partyName;
  final String? brandName;    // From products_design -> product_head
  final String? locationName; // From locations
  final String? designNo;     // From products_design
  final int productId; 
  final int designId;   
  final int locationId; 
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
    this.partyName,
    this.brandName,
    this.locationName,
    this.designNo,
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
    // Supabase can return joined data as either a Map or a List of length 1
    T? getJoinedData<T>(dynamic data) {
      if (data == null) return null;
      if (data is List) return data.isEmpty ? null : data.first as T?;
      if (data is Map) return data as T?;
      return null;
    }

    final pdData = getJoinedData<Map<String, dynamic>>(json['products_design']);
    final locData = getJoinedData<Map<String, dynamic>>(json['locations']);
    final pData = getJoinedData<Map<String, dynamic>>(json['parties']);

    String? bName;
    if (pdData != null) {
      final head = getJoinedData<Map<String, dynamic>>(pdData['product_head']);
      if (head != null) {
        final folder = getJoinedData<Map<String, dynamic>>(head['folders']);
        // Prioritize folder_name (Brand), then product_name
        bName = (folder?['folder_name'] as String?) ?? (head['product_name'] as String?);
      }
    }

    return SalesEntry(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      invoiceno: json['invoiceno'] as String,
      partyId: json['party_id'] as int,
      partyName: (pData != null) ? pData['partyname'] as String? : null,
      brandName: bName,
      locationName: (locData != null) ? locData['name'] as String? : null,
      designNo: (pdData != null) ? pdData['design_no'] as String? : null,
      productId: json['product_id'] as int,
      designId: json['design_id'] as int,
      locationId: json['location_id'] as int? ?? 0,
      quantity: json['quantity'] as int,
      rate: json['rate'] as int,
      amount: json['amount'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toIST(),
      modifiedAt: DateTime.parse(json['modified_at'] as String).toIST(),
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
