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
}
