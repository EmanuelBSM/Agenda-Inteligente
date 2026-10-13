import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_inteligente_gemini/models/agenda_event.dart';
import 'package:agenda_inteligente_gemini/models/agenda_task.dart';
import 'package:agenda_inteligente_gemini/models/chat_message.dart';
import 'package:agenda_inteligente_gemini/state/app_store.dart';

void main() {
  test('detecta conflito de horário', () {
    final store = AppStore.empty();
    final existing = AgendaEvent(
      id: 'existing',
      title: 'Aula',
      start: DateTime(2026, 10, 1, 10),
      end: DateTime(2026, 10, 1, 11),
    );
    store.addEvent(existing);
    final conflict = AgendaEvent(
      id: 'conflict',
      title: 'Conflito',
      start: DateTime(2026, 10, 1, 10, 15),
      end: DateTime(2026, 10, 1, 11, 15),
    );
    expect(store.hasConflict(conflict), isTrue);
  });

  test('tarefas preservam data e horário', () {
    final store = AppStore.empty();
    store.addTask(
      AgendaTask(
        id: 'task',
        title: 'Estudar',
        deadline: DateTime(2026, 10, 2, 18, 45),
        deadlineHasTime: true,
        priority: TaskPriority.alta,
      ),
    );
    expect(store.tasks.single.deadline, DateTime(2026, 10, 2, 18, 45));
    expect(store.tasks.single.deadlineHasTime, isTrue);
  });

  test('eventos e tarefas podem ser editados e excluídos', () {
    final store = AppStore.empty();
    final event = AgendaEvent(
      id: 'evento-crud',
      title: 'Prova antiga',
      start: DateTime(2026, 10, 20, 9),
      end: DateTime(2026, 10, 20, 10),
    );
    final task = AgendaTask(
      id: 'tarefa-crud',
      title: 'Estudar antigo',
      deadline: DateTime(2026, 10, 21, 18),
      deadlineHasTime: true,
      priority: TaskPriority.media,
    );

    store.addEvent(event);
    store.addTask(task);
    store.updateEvent(event.copyWith(
      title: 'Prova remarcada',
      start: DateTime(2026, 10, 22, 11),
      end: DateTime(2026, 10, 22, 12),
    ));
    store.updateTask(task.copyWith(
      title: 'Estudar atualizado',
      deadline: DateTime(2026, 10, 23, 19),
      deadlineHasTime: true,
      priority: TaskPriority.alta,
    ));

    expect(store.events.single.title, 'Prova remarcada');
    expect(store.events.single.start, DateTime(2026, 10, 22, 11));
    expect(store.tasks.single.title, 'Estudar atualizado');
    expect(store.tasks.single.deadline, DateTime(2026, 10, 23, 19));
    expect(store.tasks.single.priority, TaskPriority.alta);

    store.removeEvent('evento-crud');
    store.removeTask('tarefa-crud');
    expect(store.events, isEmpty);
    expect(store.tasks, isEmpty);
  });

  test('cada conversa mantém mensagens separadas', () {
    final store = AppStore.empty();
    final first = store.createThread();
    final second = store.createThread();

    store.addMessage(ChatMessage(
      id: 'm1',
      threadId: first.id,
      text: 'Matemática',
      fromUser: true,
      createdAt: DateTime(2026, 10, 1, 10),
    ));
    store.addMessage(ChatMessage(
      id: 'm2',
      threadId: second.id,
      text: 'História',
      fromUser: true,
      createdAt: DateTime(2026, 10, 1, 11),
    ));

    expect(store.messagesForThread(first.id).single.text, 'Matemática');
    expect(store.messagesForThread(second.id).single.text, 'História');
    expect(store.threadById(first.id)!.title, 'Matemática');
    expect(store.threadById(second.id)!.title, 'História');
  });
}
