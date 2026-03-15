class Folder {
  final int id;
  final String folderName;
  final int shopId;
  final bool isActive;
  final DateTime? timeAdded;

  Folder({
    required this.id,
    required this.folderName,
    required this.shopId,
    required this.isActive,
    this.timeAdded,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as int,
      folderName: json['folder_name'] as String,
      shopId: json['shop_id'] as int,
      isActive: json['is_active'] as bool? ?? true,
      timeAdded: json['time_added'] != null
          ? DateTime.parse(json['time_added'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folder_name': folderName,
      'shop_id': shopId,
      'is_active': isActive,
    };
  }
}
