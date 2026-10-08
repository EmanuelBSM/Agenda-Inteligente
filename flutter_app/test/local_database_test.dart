import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_inteligente_gemini/models/agenda_event.dart';
import 'package:agenda_inteligente_gemini/models/agenda_task.dart';
import 'package:agenda_inteligente_gemini/models/chat_message.dart';
import 'package:agenda_inteligente_gemini/models/material_item.dart';
import 'package:agenda_inteligente_gemini/services/local_auth_service.dart';
import 'package:agenda_inteligente_gemini/services/local_database.dart';
import 'package:agenda_inteligente_gemini/state/app_store.dart';

void main() {
  late LocalDatabase database;
  late LocalAuthService auth;

  setUp(() async {
    database = LocalDatabase(inMemory: true);
    await database.initialize();
    auth = LocalAuthService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('cadastro e login local validam a senha', () async {
    final created = await auth.register(name: 'Aluno Teste', email: 'aluno@teste.com', password: '123456');
    expect(created.id, greaterThan(0));
    final rows = await database.db.query('users', where: 'id = ?', whereArgs: [created.id]);
    expect(rows.single['password_hash'], isNot('123456'));
    expect((rows.single['salt'] as String).isNotEmpty, isTrue);

    final logged = await auth.login(email: 'ALUNO@TESTE.COM', password: '123456');
    expect(logged.id, created.id);
    await expectLater(auth.login(email: 'aluno@teste.com', password: 'errada'), throwsA(isA<AuthException>()));
  });

  test('redefine senha local e invalida a senha anterior', () async {
    await auth.register(name: 'Recuperação', email: 'recupera@teste.com', password: '123456');

    await auth.resetPassword(email: 'RECUPERA@TESTE.COM', newPassword: 'nova123');

    await expectLater(
      auth.login(email: 'recupera@teste.com', password: '123456'),
      throwsA(isA<AuthException>()),
    );
    final logged = await auth.login(email: 'recupera@teste.com', password: 'nova123');
    expect(logged.email, 'recupera@teste.com');
  });

  test('novo usuário começa sem dados de demonstração', () async {
    final user = await auth.register(name: 'Vazio', email: 'vazio@teste.com', password: '123456');
    final store = AppStore.local(database);
    await store.loadForUser(user);
    expect(store.events, isEmpty);
    expect(store.tasks, isEmpty);
    expect(store.materials, isEmpty);
    expect(store.threads, isEmpty);
  });

  test('eventos, tarefas, materiais e conversas persistem no SQLite local', () async {
    final user = await auth.register(name: 'Persistência', email: 'persistencia@teste.com', password: 'abcdef');
    final store = AppStore.local(database);
    await store.loadForUser(user);

    final event = AgendaEvent(
      id: 'evento-local',
      title: 'Prova local',
      start: DateTime(2026, 10, 2, 14),
      end: DateTime(2026, 10, 2, 15),
      location: 'Sala 1',
    );
    final task = AgendaTask(
      id: 'tarefa-local',
      title: 'Estudar SQLite',
      deadline: DateTime(2026, 10, 2, 18),
      deadlineHasTime: true,
      priority: TaskPriority.alta,
    );
    final material = MaterialItem(name: 'files/teste', displayName: 'teste.pdf', mimeType: 'application/pdf', remote: true);
    final thread = store.createThread();

    store.addEvent(event);
    store.addTask(task);
    store.addMaterial(material);
    store.addMessage(ChatMessage(
      id: 'chat-local',
      threadId: thread.id,
      text: 'Olá',
      fromUser: true,
      createdAt: DateTime(2026, 10, 1, 20),
    ));
    store.updateThreadInteraction(thread.id, 'interaction-1');
    await store.flush();

    final reloaded = AppStore.local(database);
    await reloaded.loadForUser(user);

    expect(reloaded.events.single.title, 'Prova local');
    expect(reloaded.tasks.single.title, 'Estudar SQLite');
    expect(reloaded.tasks.single.deadline, DateTime(2026, 10, 2, 18));
    expect(reloaded.tasks.single.deadlineHasTime, isTrue);
    expect(reloaded.materials.single.displayName, 'teste.pdf');
    expect(reloaded.threads.single.previousInteractionId, 'interaction-1');
    expect(reloaded.messagesForThread(thread.id).single.text, 'Olá');
  });

  test('duas conversas persistem sem misturar mensagens', () async {
    final user = await auth.register(name: 'Chats', email: 'chats@teste.com', password: '123456');
    final store = AppStore.local(database);
    await store.loadForUser(user);
    final a = store.createThread(title: 'Matemática');
    final b = store.createThread(title: 'História');
    store.addMessage(ChatMessage(id: 'a1', threadId: a.id, text: 'Equação', fromUser: true, createdAt: DateTime.now()));
    store.addMessage(ChatMessage(id: 'b1', threadId: b.id, text: 'Guerra Fria', fromUser: true, createdAt: DateTime.now()));
    await store.flush();

    expect((await database.loadMessages(user.id, a.id)).single.text, 'Equação');
    expect((await database.loadMessages(user.id, b.id)).single.text, 'Guerra Fria');
  });

  test('cada conversa persiste sua própria seleção de PDFs', () async {
    final user = await auth.register(name: 'PDFs', email: 'pdfs@teste.com', password: '123456');
    final store = AppStore.local(database);
    await store.loadForUser(user);
    store.addMaterial(
      const MaterialItem(name: 'files/a', displayName: 'A.pdf', mimeType: 'application/pdf', remote: true),
    );
    store.addMaterial(
      const MaterialItem(name: 'files/b', displayName: 'B.pdf', mimeType: 'application/pdf', remote: true),
    );

    final thread = store.createThread(title: 'Estudo');
    expect(thread.selectedMaterialNames, containsAll(['files/a', 'files/b']));
    store.updateThreadMaterials(thread.id, ['files/b']);
    await store.flush();

    final reloaded = AppStore.local(database);
    await reloaded.loadForUser(user);
    expect(reloaded.threadById(thread.id)!.selectedMaterialNames, ['files/b']);
  });

  test('plano de estudo sugerido permanece salvo no histórico da conversa', () async {
    final user = await auth.register(name: 'Plano', email: 'plano@teste.com', password: '123456');
    final store = AppStore.local(database);
    await store.loadForUser(user);
    final thread = store.createThread(title: 'Prova de Matemática');
    final blocks = [
      AgendaEvent(
        id: 'study-1',
        title: 'Matemática — bloco 1',
        start: DateTime(2026, 10, 6, 18),
        end: DateTime(2026, 10, 6, 19, 30),
      ),
      AgendaEvent(
        id: 'study-2',
        title: 'Matemática — bloco 2',
        start: DateTime(2026, 10, 8, 18),
        end: DateTime(2026, 10, 8, 20, 30),
      ),
    ];
    store.addMessage(ChatMessage(
      id: 'study-message',
      threadId: thread.id,
      text: 'Separei seu estudo em dois blocos.',
      fromUser: false,
      createdAt: DateTime(2026, 10, 5, 14),
      suggestedStudyBlocks: blocks,
    ));
    await store.flush();

    final loaded = await database.loadMessages(user.id, thread.id);
    expect(loaded.single.suggestedStudyBlocks, hasLength(2));
    expect(loaded.single.suggestedStudyBlocks.first.start, DateTime(2026, 10, 6, 18));
    expect(loaded.single.suggestedStudyBlocks.last.end, DateTime(2026, 10, 8, 20, 30));
  });

  test('dados ficam separados por usuário', () async {
    final first = await auth.register(name: 'Primeiro', email: 'p@teste.com', password: '123456');
    final second = await auth.register(name: 'Segundo', email: 's@teste.com', password: '123456');
    await database.upsertEvent(
      first.id,
      AgendaEvent(id: 'somente-primeiro', title: 'Privado', start: DateTime(2026, 10, 1, 10), end: DateTime(2026, 10, 1, 11)),
    );
    expect((await database.loadEvents(first.id)).length, 1);
    expect(await database.loadEvents(second.id), isEmpty);
  });
}
