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
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.store,
    required this.authService,
  });

  final AppStore store;
  final AuthService authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _restoringSession = false;

  @override
  void initState() {
    super.initState();
    if (widget.store.hasLocalDatabase) {
      _restoringSession = true;
      _restoreSession();
    }
  }

  Future<void> _restoreSession() async {
    try {
      await widget.store.restoreSession();
    } catch (_) {
      // Se a sessão estiver inválida, o app continua permitindo login manual.
    } finally {
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringSession) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (widget.store.currentUser == null) {
          return LoginScreen(store: widget.store, authService: widget.authService);
        }
        return MainShell(store: widget.store);
      },
    );
  }
}
