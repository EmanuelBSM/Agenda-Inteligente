import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_inteligente_gemini/models/agenda_event.dart';
import 'package:agenda_inteligente_gemini/models/agenda_task.dart';
import 'package:agenda_inteligente_gemini/models/chat_message.dart';
import 'package:agenda_inteligente_gemini/state/app_store.dart';

void main() {
  test('detecta conflito de horário', () {
    final store = AppStore.memory();
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

  test('tarefas preservam data e horário em memória', () {
    final store = AppStore.memory();
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

  test('cada conversa mantém mensagens separadas durante a sessão', () {
    final store = AppStore.memory();
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

  test('novo AppStore começa vazio e não recupera estado anterior', () {
    final first = AppStore.memory();
    first.addEvent(
      AgendaEvent(
        id: 'temporario',
        title: 'Temporário',
        start: DateTime(2026, 10, 5, 10),
        end: DateTime(2026, 10, 5, 11),
      ),
    );
    expect(first.events, hasLength(1));

    final reopened = AppStore.memory();
    expect(reopened.events, isEmpty);
    expect(reopened.tasks, isEmpty);
    expect(reopened.threads, isEmpty);
    expect(reopened.materials, isEmpty);
  });
}
