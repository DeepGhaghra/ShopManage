class FolderDistribution {
  final int id;
  final int partyId;
  final int folderId;
  final int quantity;
  final DateTime timeAdded;
  final int shopId;
  final String? partyName; // Joined field
  final String? folderName; // Joined field

  FolderDistribution({
    required this.id,
    required this.partyId,
    required this.folderId,
    required this.quantity,
    required this.timeAdded,
    required this.shopId,
    this.partyName,
    this.folderName,
  });

  factory FolderDistribution.fromJson(Map<String, dynamic> json) {
    return FolderDistribution(
      id: json['id'] as int,
      partyId: json['party_id'] as int,
      folderId: json['folder_id'] as int,
      quantity: json['quantity'] as int,
      timeAdded: DateTime.parse(json['time_added'] as String),
      shopId: json['shop_id'] as int,
      partyName: json['parties']?['partyname'] as String?,
      folderName: json['folders']?['folder_name'] as String?,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'party_id': partyId,
      'folder_id': folderId,
      'quantity': quantity,
      'shop_id': shopId,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
