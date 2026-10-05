import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../widgets/formatters.dart';
import '../widgets/soft_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.store,
    required this.onNavigate,
  });

  final AppStore store;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final today = DateTime.now();
        final events = store.eventsForDay(today);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agenda Inteligente\ncom Gemini',
                  style: TextStyle(fontSize: 25, height: 1.05, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 26),
                const Text('Olá!', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Bem vindo!',
                  style: TextStyle(fontSize: 15, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 24),
                _SummaryCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Compromissos hoje',
                  value: '${events.length}',
                  onTap: () => onNavigate(1),
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Tarefas pendentes',
                  value: '${store.pendingTaskCount}',
                  onTap: () => onNavigate(2),
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  icon: Icons.description_rounded,
                  label: 'Materiais nesta sessão',
                  value: '${store.materials.length}',
                  onTap: () => onNavigate(4),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const Expanded(child: Text('Próximos compromissos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    TextButton(onPressed: () => onNavigate(1), child: const Text('Ver todos')),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE3E3E3)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: events.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('Nenhum compromisso hoje.'),
                        )
                      : Column(
                          children: events.take(3).map((event) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle, size: 10, color: Color(0xFF626262)),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 52,
                                    child: Text(formatTime(event.start), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                        Text(event.location ?? 'Sem local', style: const TextStyle(fontSize: 13, color: Color(0xFF777777))),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(color: Color(0xFFEFEFEF), shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: const Color(0xFF4A4A4A)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF555555)),
        ],
      ),
    );
  }
}
