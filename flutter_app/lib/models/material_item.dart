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

  Map<String, dynamic> toDbMap(int userId) => {
        'name': name,
        'user_id': userId,
        'display_name': displayName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'create_time': createTime?.toIso8601String(),
        'uri': uri,
        'state': state,
        'category': category,
        'remote': remote ? 1 : 0,
      };

  factory MaterialItem.fromDbMap(Map<String, Object?> map) {
    return MaterialItem(
      name: map['name']! as String,
      displayName: map['display_name']! as String,
      mimeType: map['mime_type']! as String,
      sizeBytes: map['size_bytes'] as int?,
      createTime: map['create_time'] == null ? null : DateTime.tryParse(map['create_time']! as String),
      uri: map['uri'] as String?,
      state: map['state'] as String?,
      category: map['category'] as String? ?? 'Todos',
      remote: (map['remote'] as int? ?? 0) == 1,
    );
  }
}
