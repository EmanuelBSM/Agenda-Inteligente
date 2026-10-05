import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_inteligente_gemini/screens/main_shell.dart';
import 'package:agenda_inteligente_gemini/state/app_store.dart';

Future<void> pumpApp(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(home: MainShell(store: store)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('aplicativo abre direto sem login', (tester) async {
    final store = AppStore.memory();
    await pumpApp(tester, store);

    expect(find.text('Agenda Inteligente\ncom Gemini'), findsOneWidget);
    expect(find.text('Olá!'), findsOneWidget);
    expect(find.textContaining('apenas enquanto o app estiver aberto'), findsOneWidget);
  });

  testWidgets('menu principal mantém as cinco áreas da v6.1', (tester) async {
    final store = AppStore.memory();
    await pumpApp(tester, store);

    final nav = find.byType(BottomNavigationBar);
    for (final label in ['Início', 'Calendário', 'Tarefas', 'Gemini', 'Materiais']) {
      expect(find.descendant(of: nav, matching: find.text(label)), findsOneWidget);
    }
  });

  testWidgets('Gemini continua com conversas separadas durante a sessão', (tester) async {
    final store = AppStore.memory();
    await pumpApp(tester, store);

    final nav = find.byType(BottomNavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('Gemini')));
    await tester.pumpAndSettle();

    expect(find.text('Conversas com Gemini'), findsOneWidget);
    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-new-chat')));
    await tester.pumpAndSettle();
    expect(find.text('Nova conversa'), findsOneWidget);
    expect(find.byKey(const Key('assistant-input')), findsOneWidget);
  });
}
