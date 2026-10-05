import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'state/app_store.dart';

void main() {
  runApp(const AgendaInteligenteApp());
}

class AgendaInteligenteApp extends StatefulWidget {
  const AgendaInteligenteApp({super.key});

  @override
  State<AgendaInteligenteApp> createState() => _AgendaInteligenteAppState();
}

class _AgendaInteligenteAppState extends State<AgendaInteligenteApp> {
  late final AppStore store;

  @override
  void initState() {
    super.initState();
    store = AppStore.memory();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agenda Inteligente com Gemini',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF303030),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF303030),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF141414),
          outline: const Color(0xFFD9D9D9),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 16, height: 1.25),
          bodyMedium: TextStyle(fontSize: 14, height: 1.25),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF303030), width: 1.4),
          ),
        ),
      ),
      home: MainShell(store: store),
    );
  }
}
