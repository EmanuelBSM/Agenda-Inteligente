import 'package:flutter/material.dart';

import '../services/local_auth_service.dart';
import '../state/app_store.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Mantém a autenticação fora da pilha do Navigator.
///
/// Ao carregar/limpar o usuário no [AppStore], somente o conteúdo desta rota é
/// trocado. Isso evita substituir a rota de login enquanto um AlertDialog ainda
/// está concluindo sua desmontagem no Windows.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.store,
    required this.authService,
  });

  final AppStore store;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.currentUser == null) {
          return LoginScreen(store: store, authService: authService);
        }
        return MainShell(store: store);
      },
    );
  }
}
