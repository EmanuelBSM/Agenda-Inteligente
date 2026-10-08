import 'dart:convert';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.previousInteractionId,
    this.selectedMaterialNames = const [],
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? previousInteractionId;
  final List<String> selectedMaterialNames;

  ChatThread copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? previousInteractionId,
    bool clearPreviousInteractionId = false,
    List<String>? selectedMaterialNames,
  }) {
    return ChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      previousInteractionId: clearPreviousInteractionId
          ? null
          : (previousInteractionId ?? this.previousInteractionId),
      selectedMaterialNames: selectedMaterialNames ?? this.selectedMaterialNames,
    );
  }

  Map<String, dynamic> toDbMap(int userId) => {
        'id': id,
        'user_id': userId,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'previous_interaction_id': previousInteractionId,
        'selected_material_names_json': jsonEncode(selectedMaterialNames),
      };

  factory ChatThread.fromDbMap(Map<String, Object?> map) {
    final selectedMaterialNames = <String>[];
    final rawSelected = map['selected_material_names_json']?.toString();
    if (rawSelected != null && rawSelected.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSelected);
        if (decoded is List) {
          selectedMaterialNames.addAll(
            decoded.map((item) => item.toString()).where((item) => item.isNotEmpty),
          );
        }
      } catch (_) {
        // Mantém a conversa utilizável mesmo se uma versão antiga tiver dados inválidos.
      }
    }
    return ChatThread(
      id: map['id']! as String,
      title: map['title']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      previousInteractionId: map['previous_interaction_id'] as String?,
      selectedMaterialNames: selectedMaterialNames,
    );
  }
}
