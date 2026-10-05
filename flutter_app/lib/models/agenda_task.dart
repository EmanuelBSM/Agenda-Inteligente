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
}
