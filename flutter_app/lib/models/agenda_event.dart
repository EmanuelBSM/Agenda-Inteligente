class AgendaEvent {
  const AgendaEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? location;

  AgendaEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    String? description,
    String? location,
  }) {
    return AgendaEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      description: description ?? this.description,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'description': description,
        'location': location,
      };

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'description': description,
        'location': location,
      };

  factory AgendaEvent.fromDbMap(Map<String, Object?> map) {
    return AgendaEvent(
      id: map['id']! as String,
      title: map['title']! as String,
      start: DateTime.parse(map['start']! as String),
      end: DateTime.parse(map['end']! as String),
      description: map['description'] as String?,
      location: map['location'] as String?,
    );
  }
}
