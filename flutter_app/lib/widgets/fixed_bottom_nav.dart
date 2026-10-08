import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FixedBottomNav extends StatelessWidget {
  const FixedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Início'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month_rounded), label: 'Calendário'),
    BottomNavigationBarItem(icon: Icon(Icons.check_box_outlined), activeIcon: Icon(Icons.check_box_rounded), label: 'Tarefas'),
    BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome_rounded), label: 'Gemini'),
    BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description_rounded), label: 'Materiais'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x0F11182D), blurRadius: 14, offset: Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.muted,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            iconSize: 27,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            elevation: 0,
            items: items,
          ),
        ),
      ),
    );
  }
}
