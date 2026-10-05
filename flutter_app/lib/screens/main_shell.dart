import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../state/app_store.dart';
import '../widgets/fixed_bottom_nav.dart';
import 'assistant_tab.dart';
import 'calendar_tab.dart';
import 'home_tab.dart';
import 'materials_tab.dart';
import 'tasks_tab.dart';

class MainShell extends StatefulWidget {
  MainShell({
    super.key,
    required this.store,
    ApiService? apiService,
  }) : apiService = apiService ?? ApiService();

  final AppStore store;
  final ApiService apiService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(
        store: widget.store,
        onNavigate: (value) => setState(() => index = value),
      ),
      CalendarTab(store: widget.store),
      TasksTab(store: widget.store),
      AssistantTab(store: widget.store, apiService: widget.apiService),
      MaterialsTab(store: widget.store, apiService: widget.apiService),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: FixedBottomNav(
        currentIndex: index,
        onTap: (value) => setState(() => index = value),
      ),
    );
  }
}
