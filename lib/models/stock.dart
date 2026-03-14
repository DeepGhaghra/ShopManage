import '../utils/date_utils.dart';

class Stock {
  final int id;
  final int designId;
  final int locationId;
  final int quantity;
  final DateTime timeAdded;
  final DateTime? modifiedAt;
  final int shopId;

  Stock({
    required this.id,
    required this.designId,
    required this.locationId,
    required this.quantity,
    required this.timeAdded,
    this.modifiedAt,
    required this.shopId,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      id: json['id'] as int,
      designId: json['design_id'] as int,
      locationId: json['location_id'] as int,
      quantity: json['quantity'] as int,
      timeAdded: DateTime.parse(json['time_added'] as String).toIST(),
      modifiedAt: json['modified_at'] != null ? DateTime.parse(json['modified_at'] as String).toIST() : null,
      shopId: json['shop_id'] as int,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'design_id': designId,
      'location_id': locationId,
      'quantity': quantity,
      'modified_at': modifiedAt?.toIso8601String(),
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
