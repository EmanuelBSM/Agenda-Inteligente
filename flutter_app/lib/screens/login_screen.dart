import 'package:flutter/material.dart';

import '../services/local_auth_service.dart';
import '../state/app_store.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.store,
    required this.authService,
  });

  final AppStore store;
  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final user = await widget.authService.login(
        email: emailController.text,
        password: passwordController.text,
      );
      await widget.store.loadForUser(user);
      if (!mounted) return;
      // O AuthGate em main.dart troca a tela automaticamente após o store
      // carregar o usuário. Evitamos substituir a rota durante a desmontagem
      // de widgets/overlays, o que pode disparar _dependents.isEmpty.
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Não foi possível acessar o banco local.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _register() async {
    final result = await showDialog<_RegisterData>(
      context: context,
      barrierDismissible: !loading,
      builder: (dialogContext) => _RegisterDialog(
        initialEmail: emailController.text.trim(),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => loading = true);
    try {
      final user = await widget.authService.register(
        name: result.name,
        email: result.email,
        password: result.password,
      );
      await widget.store.loadForUser(user);
      if (!mounted) return;
      // O AuthGate observa o AppStore e exibe a tela principal.
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Não foi possível criar a conta local.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(size: 112),
                      const SizedBox(height: 18),
                      const Text(
                        'Agenda Inteligente\ncom Gemini',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, height: 1.08, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Seus estudos, compromissos e\nmateriais, com o poder da IA.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, color: Color(0xFF666666), height: 1.35),
                      ),
                      const SizedBox(height: 42),
                      TextField(
                        key: const Key('login-email'),
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                        decoration: const InputDecoration(
                          hintText: 'Seu e-mail',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('login-password'),
                        controller: passwordController,
                        obscureText: obscurePassword,
                        onSubmitted: (_) => _enter(),
                        decoration: InputDecoration(
                          hintText: 'Sua senha',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          key: const Key('login-enter'),
                          onPressed: loading ? null : _enter,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3B3B3B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: loading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Entrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('ou', style: TextStyle(color: Color(0xFF666666), fontSize: 16)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          key: const Key('login-register'),
                          onPressed: loading ? null : _register,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Color(0xFF555555)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Criar conta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController(text: widget.initialEmail);
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      _RegisterData(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Criar conta'),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('register-name'),
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => (value ?? '').trim().length < 2 ? 'Informe seu nome.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('register-email'),
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) => (value ?? '').contains('@') ? null : 'Informe um e-mail válido.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('register-password'),
                controller: passwordController,
                obscureText: true,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  helperText: 'Mínimo de 6 caracteres',
                ),
                validator: (value) => (value ?? '').length < 6 ? 'Use pelo menos 6 caracteres.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('register-submit'),
          onPressed: _submit,
          child: const Text('Criar conta'),
        ),
      ],
    );
  }
}

class _RegisterData {
  const _RegisterData({required this.name, required this.email, required this.password});
  final String name;
  final String email;
  final String password;
}
