import 'package:agenda_inteligente_gemini/models/agenda_event.dart';
import 'package:agenda_inteligente_gemini/models/agenda_task.dart';
import 'package:agenda_inteligente_gemini/models/chat_message.dart';
import 'package:agenda_inteligente_gemini/models/material_item.dart';
import 'package:agenda_inteligente_gemini/services/local_database.dart';
import 'package:agenda_inteligente_gemini/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase database;

  setUp(() async {
    database = LocalDatabase(inMemory: true);
    await database.initialize();
  });

  tearDown(() async {
    await database.close();
  });

  test('eventos tarefas e materiais persistem no SQLite', () async {
    final store = AppStore.local(database);
    await store.loadCoreData();

    store.addEvent(
      AgendaEvent(
        id: 'evento-1',
        title: 'Prova',
        start: DateTime(2026, 10, 10, 14),
        end: DateTime(2026, 10, 10, 15),
      ),
    );
    store.addTask(
      AgendaTask(
        id: 'tarefa-1',
        title: 'Estudar',
        deadline: DateTime(2026, 10, 9, 18),
        deadlineHasTime: true,
        priority: TaskPriority.alta,
      ),
    );
    store.addMaterial(
      const MaterialItem(
        name: 'files/apostila',
        displayName: 'apostila.pdf',
        mimeType: 'application/pdf',
        remote: true,
      ),
    );
    await store.flush();

    final reloaded = AppStore.local(database);
    await reloaded.loadCoreData();

    expect(reloaded.events.single.title, 'Prova');
    expect(reloaded.tasks.single.deadline, DateTime(2026, 10, 9, 18));
    expect(reloaded.tasks.single.deadlineHasTime, isTrue);
    expect(reloaded.materials.single.displayName, 'apostila.pdf');
  });

  test('conversas diferentes mantem historicos separados', () async {
    final store = AppStore.local(database);
    await store.loadChats();
    final matematica = store.createThread(title: 'Matemática');
    final historia = store.createThread(title: 'História');

    store.addMessage(
      ChatMessage(
        id: 'msg-mat',
        threadId: matematica.id,
        text: 'Polinômios',
        fromUser: true,
        createdAt: DateTime(2026, 10, 5, 10),
      ),
    );
    store.addMessage(
      ChatMessage(
        id: 'msg-hist',
        threadId: historia.id,
        text: 'Era Vargas',
        fromUser: true,
        createdAt: DateTime(2026, 10, 5, 11),
      ),
    );
    await store.flush();

    final reloaded = AppStore.local(database);
    await reloaded.loadChats();

    expect(reloaded.messagesForThread(matematica.id).single.text, 'Polinômios');
    expect(reloaded.messagesForThread(historia.id).single.text, 'Era Vargas');
  });

  test('blocos de estudo continuam no historico apos recarregar', () async {
    final store = AppStore.local(database);
    final thread = store.createThread(title: 'Prova');
    store.addMessage(
      ChatMessage(
        id: 'plano-1',
        threadId: thread.id,
        text: 'Plano criado.',
        fromUser: false,
        createdAt: DateTime(2026, 10, 5, 14),
        suggestedStudyBlocks: [
          AgendaEvent(
            id: 'bloco-1',
            title: 'Estudar matemática',
            start: DateTime(2026, 10, 6, 18),
            end: DateTime(2026, 10, 6, 19, 30),
          ),
        ],
      ),
    );
    await store.flush();

    final messages = await database.loadMessages(thread.id);
    expect(messages.single.suggestedStudyBlocks, hasLength(1));
    expect(messages.single.suggestedStudyBlocks.single.start, DateTime(2026, 10, 6, 18));
  });
}
