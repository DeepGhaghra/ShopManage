class FolderTransaction {
  final int id;
  final int shopId;
  final int partyId;
  final int folderId;
  final String transactionType; // 'GIVE' or 'RETURN'
  final int quantity;
  final DateTime timeAdded;
  final String? partyName; // Joined
  final String? folderName; // Joined

  FolderTransaction({
    required this.id,
    required this.shopId,
    required this.partyId,
    required this.folderId,
    required this.transactionType,
    required this.quantity,
    required this.timeAdded,
    this.partyName,
    this.folderName,
  });

  factory FolderTransaction.fromJson(Map<String, dynamic> json) {
    return FolderTransaction(
      id: json['id'] as int,
      shopId: json['shop_id'] as int,
      partyId: json['party_id'] as int,
      folderId: json['folder_id'] as int,
      transactionType: json['transaction_type'] as String,
      quantity: json['quantity'] as int,
      timeAdded: DateTime.parse(json['time_added'] as String),
      partyName: json['parties']?['partyname'] as String?,
      folderName: json['folders']?['folder_name'] as String?,
    );
  }

  Map<String, dynamic> toJson({bool excludeId = false}) {
    final data = <String, dynamic>{
      'shop_id': shopId,
      'party_id': partyId,
      'folder_id': folderId,
      'transaction_type': transactionType,
      'quantity': quantity,
    };
    if (!excludeId) {
      data['id'] = id;
    }
    return data;
  }
}
