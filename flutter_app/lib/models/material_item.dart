class MaterialItem {
  const MaterialItem({
    required this.name,
    required this.displayName,
    required this.mimeType,
    this.sizeBytes,
    this.createTime,
    this.uri,
    this.state,
    this.category = 'Todos',
    this.remote = false,
  });

  final String name;
  final String displayName;
  final String mimeType;
  final int? sizeBytes;
  final DateTime? createTime;
  final String? uri;
  final String? state;
  final String category;
  final bool remote;

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      name: (json['name'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['display_name'] ?? 'Arquivo').toString(),
      mimeType: (json['mimeType'] ?? json['mime_type'] ?? 'application/octet-stream').toString(),
      sizeBytes: int.tryParse('${json['sizeBytes'] ?? ''}'),
      createTime: json['createTime'] != null ? DateTime.tryParse('${json['createTime']}') : null,
      uri: json['uri']?.toString(),
      state: json['state']?.toString(),
      category: (json['category'] ?? 'Todos').toString(),
      remote: true,
    );
  }
}
