import 'dart:convert';

import 'agenda_event.dart';
import 'agenda_task.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.text,
    required this.fromUser,
    required this.createdAt,
    this.suggestedEvent,
    this.suggestedTask,
    this.suggestedStudyBlocks = const [],
  });

  final String id;
  final String threadId;
  final String text;
  final bool fromUser;
  final DateTime createdAt;
  final AgendaEvent? suggestedEvent;
  final AgendaTask? suggestedTask;
  final List<AgendaEvent> suggestedStudyBlocks;

  Map<String, dynamic> toDbMap(int userId) => {
        'id': id,
        'user_id': userId,
        'thread_id': threadId,
        'text': text,
        'from_user': fromUser ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'event_id': suggestedEvent?.id,
        'event_title': suggestedEvent?.title,
        'event_start': suggestedEvent?.start.toIso8601String(),
        'event_end': suggestedEvent?.end.toIso8601String(),
        'event_description': suggestedEvent?.description,
        'event_location': suggestedEvent?.location,
        'task_id': suggestedTask?.id,
        'task_title': suggestedTask?.title,
        'task_deadline': suggestedTask?.deadline?.toIso8601String(),
        'task_deadline_has_time': suggestedTask == null ? null : (suggestedTask!.deadlineHasTime ? 1 : 0),
        'task_priority': suggestedTask?.priority.name,
        'study_blocks_json': suggestedStudyBlocks.isEmpty
            ? null
            : jsonEncode(suggestedStudyBlocks.map((event) => event.toJson()).toList()),
      };

  factory ChatMessage.fromDbMap(Map<String, Object?> map) {
    AgendaEvent? event;
    final start = map['event_start'] as String?;
    final end = map['event_end'] as String?;
    final eventTitle = map['event_title'] as String?;
    if (start != null && end != null && eventTitle != null) {
      event = AgendaEvent(
        id: map['event_id'] as String? ?? 'saved-${map['id']}',
        title: eventTitle,
        start: DateTime.parse(start),
        end: DateTime.parse(end),
        description: map['event_description'] as String?,
        location: map['event_location'] as String?,
      );
    }

    AgendaTask? task;
    final taskTitle = map['task_title'] as String?;
    if (taskTitle != null && taskTitle.trim().isNotEmpty) {
      final rawPriority = map['task_priority']?.toString() ?? TaskPriority.media.name;
      final priority = TaskPriority.values.firstWhere(
        (value) => value.name == rawPriority,
        orElse: () => TaskPriority.media,
      );
      final rawDeadline = map['task_deadline'] as String?;
      task = AgendaTask(
        id: map['task_id'] as String? ?? 'saved-task-${map['id']}',
        title: taskTitle,
        deadline: rawDeadline == null ? null : DateTime.tryParse(rawDeadline),
        deadlineHasTime: (map['task_deadline_has_time'] as int? ?? 0) == 1,
        priority: priority,
      );
    }

    final studyBlocks = <AgendaEvent>[];
    final rawStudyBlocks = map['study_blocks_json'] as String?;
    if (rawStudyBlocks != null && rawStudyBlocks.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStudyBlocks);
        if (decoded is List) {
          for (var index = 0; index < decoded.length; index += 1) {
            final item = decoded[index];
            if (item is! Map) continue;
            final block = Map<String, dynamic>.from(item);
            final start = DateTime.tryParse('${block['start'] ?? ''}');
            final end = DateTime.tryParse('${block['end'] ?? ''}');
            final title = '${block['title'] ?? ''}'.trim();
            if (start == null || end == null || !end.isAfter(start) || title.isEmpty) continue;
            studyBlocks.add(
              AgendaEvent(
                id: '${block['id'] ?? 'saved-study-${map['id']}-$index'}',
                title: title,
                start: start,
                end: end,
                description: block['description']?.toString(),
                location: block['location']?.toString(),
              ),
            );
          }
        }
      } catch (_) {
        // Uma mensagem antiga ou corrompida não deve impedir o carregamento do chat.
      }
    }

    return ChatMessage(
      id: map['id']! as String,
      threadId: map['thread_id'] as String? ?? 'legacy',
      text: map['text']! as String,
      fromUser: (map['from_user'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at']! as String),
      suggestedEvent: event,
      suggestedTask: task,
      suggestedStudyBlocks: studyBlocks,
    );
  }
}
