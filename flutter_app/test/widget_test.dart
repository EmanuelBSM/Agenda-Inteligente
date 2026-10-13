import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_inteligente_gemini/models/user_account.dart';
import 'package:agenda_inteligente_gemini/screens/auth_gate.dart';
import 'package:agenda_inteligente_gemini/screens/calendar_tab.dart';
import 'package:agenda_inteligente_gemini/screens/tasks_tab.dart';
import 'package:agenda_inteligente_gemini/services/local_auth_service.dart';
import 'package:agenda_inteligente_gemini/state/app_store.dart';

class FakeAuthService implements AuthService {
  @override
  Future<UserAccount> login({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) throw const AuthException('Informe e-mail e senha.');
    return const UserAccount(id: 1, name: 'Estudante Teste', email: 'teste@agenda.local');
  }

  @override
  Future<UserAccount> register({required String name, required String email, required String password}) async {
    return UserAccount(id: 1, name: name, email: email);
  }

  @override
  Future<void> resetPassword({required String email, required String newPassword}) async {
    if (email.isEmpty || newPassword.length < 6) throw const AuthException('Dados inválidos.');
  }
}

Future<void> pumpAuthApp(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuthGate(store: store, authService: FakeAuthService()),
    ),
  );
}

Future<void> login(WidgetTester tester, AppStore store) async {
  await pumpAuthApp(tester, store);
  await tester.enterText(find.byKey(const Key('login-email')), 'teste@agenda.local');
  await tester.enterText(find.byKey(const Key('login-password')), '123456');
  await tester.tap(find.byKey(const Key('login-enter')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login troca para o shell principal sem substituir a rota', (tester) async {
    final store = AppStore.empty();
    await login(tester, store);
    final nav = find.byType(BottomNavigationBar);
    for (final label in ['Início', 'Calendário', 'Tarefas', 'Gemini', 'Materiais']) {
      expect(find.descendant(of: nav, matching: find.text(label)), findsOneWidget);
    }
    expect(find.text('Olá, Estudante Teste!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro fecha o dialogo antes de trocar a tela e não gera assertion', (tester) async {
    final store = AppStore.empty();
    await pumpAuthApp(tester, store);

    await tester.tap(find.byKey(const Key('login-register')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('register-name')), 'Novo Aluno');
    await tester.enterText(find.byKey(const Key('register-email')), 'novo@agenda.local');
    await tester.enterText(find.byKey(const Key('register-password')), '123456');
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Novo Aluno!'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout volta ao login sem manipular a pilha do Navigator', (tester) async {
    final store = AppStore.empty();
    await login(tester, store);

    // HomeTab expõe o logout no botão de sino/menu conforme a implementação atual;
    // aqui validamos diretamente o gate para evitar acoplamento visual.
    await store.clearUser();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-enter')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redefinição de senha local abre dialogo e conclui', (tester) async {
    final store = AppStore.empty();
    await pumpAuthApp(tester, store);

    await tester.enterText(find.byKey(const Key('login-email')), 'teste@agenda.local');
    await tester.tap(find.byKey(const Key('login-reset-password')));
    await tester.pumpAndSettle();

    expect(find.text('Redefinir senha'), findsWidgets);
    await tester.enterText(find.byKey(const Key('reset-password')), '654321');
    await tester.enterText(find.byKey(const Key('reset-confirm-password')), '654321');
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Senha redefinida. Entre com a nova senha.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('criar conta mantém conteúdo rolável no diálogo mobile', (tester) async {
    final store = AppStore.empty();
    await pumpAuthApp(tester, store);
    await tester.tap(find.byKey(const Key('login-register')));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('redefinir senha mantém conteúdo rolável no diálogo mobile', (tester) async {
    final store = AppStore.empty();
    await pumpAuthApp(tester, store);
    await tester.tap(find.byKey(const Key('login-reset-password')));
    await tester.pumpAndSettle();

    expect(find.text('Redefinir senha'), findsWidgets);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('modal de nova tarefa respeita SafeArea e permite rolagem', (tester) async {
    final store = AppStore.empty();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TasksTab(store: store))));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(SafeArea)),
      findsWidgets,
    );
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('modal de novo evento respeita SafeArea e permite rolagem', (tester) async {
    final store = AppStore.empty();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CalendarTab(store: store))));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Novo evento'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(SafeArea)),
      findsWidgets,
    );
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gemini abre lista de conversas separadas', (tester) async {
    final store = AppStore.empty();
    await login(tester, store);
    final nav = find.byType(BottomNavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('Gemini')));
    await tester.pumpAndSettle();
    expect(find.text('Conversas com Gemini'), findsOneWidget);
    expect(find.text('Nenhuma conversa ainda.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-new-chat')));
    await tester.pumpAndSettle();
    expect(find.text('Nova conversa'), findsOneWidget);
    expect(find.byKey(const Key('assistant-input')), findsOneWidget);
    expect(find.byKey(const Key('assistant-mic')), findsOneWidget);
  });
}
