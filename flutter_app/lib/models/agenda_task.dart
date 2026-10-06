enum TaskPriority { alta, media, baixa }

class AgendaTask {
  const AgendaTask({
    required this.id,
    required this.title,
    required this.deadline,
    required this.priority,
    this.deadlineHasTime = false,
    this.completed = false,
  });

  final String id;
  final String title;
  final DateTime? deadline;
  final bool deadlineHasTime;
  final TaskPriority priority;
  final bool completed;

  AgendaTask copyWith({
    String? id,
    String? title,
    DateTime? deadline,
    bool? deadlineHasTime,
    TaskPriority? priority,
    bool? completed,
  }) {
    return AgendaTask(
      id: id ?? this.id,
      title: title ?? this.title,
      deadline: deadline ?? this.deadline,
      deadlineHasTime: deadlineHasTime ?? this.deadlineHasTime,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'deadline': deadline?.toIso8601String(),
        'deadline_has_time': deadlineHasTime ? 1 : 0,
        'priority': priority.name,
        'completed': completed ? 1 : 0,
      };

  factory AgendaTask.fromDbMap(Map<String, Object?> map) {
    final priorityName = map['priority']?.toString() ?? TaskPriority.media.name;
    return AgendaTask(
      id: map['id']! as String,
      title: map['title']! as String,
      deadline: map['deadline'] == null ? null : DateTime.tryParse(map['deadline']! as String),
      deadlineHasTime: (map['deadline_has_time'] as int? ?? 0) == 1,
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == priorityName,
        orElse: () => TaskPriority.media,
      ),
      completed: (map['completed'] as int? ?? 0) == 1,
    );
  }
}
