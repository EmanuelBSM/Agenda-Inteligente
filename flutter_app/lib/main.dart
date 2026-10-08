import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/local_auth_service.dart';
import 'services/local_database.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = LocalDatabase();
  await database.initialize();
  runApp(AgendaInteligenteApp(database: database));
}

class AgendaInteligenteApp extends StatefulWidget {
  const AgendaInteligenteApp({super.key, required this.database});

  final LocalDatabase database;

  @override
  State<AgendaInteligenteApp> createState() => _AgendaInteligenteAppState();
}

class _AgendaInteligenteAppState extends State<AgendaInteligenteApp> {
  late final AppStore store;
  late final AuthService authService;

  @override
  void initState() {
    super.initState();
    store = AppStore.local(widget.database);
    authService = LocalAuthService(widget.database);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agenda Inteligente com Gemini',
      theme: buildAgendaTheme(),
      home: AuthGate(store: store, authService: authService),
    );
  }
}
