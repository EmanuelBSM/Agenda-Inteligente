class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.previousInteractionId,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? previousInteractionId;

  ChatThread copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? previousInteractionId,
    bool clearPreviousInteractionId = false,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      previousInteractionId: clearPreviousInteractionId
          ? null
          : (previousInteractionId ?? this.previousInteractionId),
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'previous_interaction_id': previousInteractionId,
      };

  factory ChatThread.fromDbMap(Map<String, Object?> map) {
    return ChatThread(
      id: map['id']! as String,
      title: map['title']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      previousInteractionId: map['previous_interaction_id'] as String?,
    );
  }
}
