import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_inteligente_gemini/models/agenda_event.dart';
import 'package:agenda_inteligente_gemini/models/agenda_task.dart';
import 'package:agenda_inteligente_gemini/screens/calendar_tab.dart';
import 'package:agenda_inteligente_gemini/screens/tasks_tab.dart';
import 'package:agenda_inteligente_gemini/state/app_store.dart';

void main() {
  testWidgets('um evento pode ser editado e excluído pela tela de calendário', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final store = AppStore.empty();
    store.addEvent(AgendaEvent(
      id: 'evento-ui-crud',
      title: 'Evento original',
      start: DateTime(day.year, day.month, day.day, 10),
      end: DateTime(day.year, day.month, day.day, 11),
      location: 'Sala A',
    ));

    await tester.pumpWidget(MaterialApp(home: CalendarTab(store: store)));
    await tester.pumpAndSettle();

    final eventMenu = find.byKey(const Key('event-actions-evento-ui-crud'));
    await tester.ensureVisible(eventMenu);
    await tester.tap(eventMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar').last);
    await tester.pumpAndSettle();

    expect(find.text('Editar evento'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('event-title-input')), 'Evento editado');
    await tester.ensureVisible(find.byKey(const Key('event-save')));
    await tester.tap(find.byKey(const Key('event-save')));
    await tester.pumpAndSettle();

    expect(store.events.single.title, 'Evento editado');

    await tester.ensureVisible(find.byKey(const Key('event-actions-evento-ui-crud')));
    await tester.tap(find.byKey(const Key('event-actions-evento-ui-crud')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-event')));
    await tester.pumpAndSettle();

    expect(store.events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uma tarefa pode ser editada e excluída pela tela de tarefas', (tester) async {
    final now = DateTime.now();
    final store = AppStore.empty();
    store.addTask(AgendaTask(
      id: 'tarefa-ui-crud',
      title: 'Tarefa original',
      deadline: DateTime(now.year, now.month, now.day, 17),
      deadlineHasTime: true,
      priority: TaskPriority.media,
    ));

    await tester.pumpWidget(MaterialApp(home: TasksTab(store: store)));
    await tester.pumpAndSettle();

    final taskMenu = find.byKey(const Key('task-actions-tarefa-ui-crud'));
    await tester.tap(taskMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar').last);
    await tester.pumpAndSettle();

    expect(find.text('Editar tarefa'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('task-title-input')), 'Tarefa editada');
    await tester.ensureVisible(find.byKey(const Key('task-save')));
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();

    expect(store.tasks.single.title, 'Tarefa editada');
    expect(store.tasks.single.deadlineHasTime, isTrue);
    expect(store.tasks.single.completed, isFalse);

    await tester.tap(find.byKey(const Key('task-actions-tarefa-ui-crud')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-task')));
    await tester.pumpAndSettle();

    expect(store.tasks, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
