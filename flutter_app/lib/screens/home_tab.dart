import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import '../widgets/soft_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.store,
    required this.onNavigate,
    required this.onLogout,
  });

  final AppStore store;
  final ValueChanged<int> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final today = DateTime.now();
        final events = store.eventsForDay(today);
        final firstName =
            store.currentUser?.name.trim().split(RegExp(r'\s+')).first ??
                'Estudante';

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Agenda Inteligente\ncom Gemini',
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Conta',
                      icon: const Icon(
                        Icons.account_circle_outlined,
                        size: 30,
                        color: AppColors.ink,
                      ),
                      onSelected: (value) {
                        if (value == 'logout') {
                          onLogout();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Text(store.currentUser?.email ?? ''),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Text('Sair'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  'Olá, $firstName!',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Aqui está o seu resumo de hoje.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                _SummaryCard(
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.softBlue,
                  label: 'Compromissos hoje',
                  value: '${events.length}',
                  onTap: () => onNavigate(1),
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  icon: Icons.check_rounded,
                  iconColor: AppColors.success,
                  iconBackground: AppColors.softGreen,
                  label: 'Tarefas pendentes',
                  value: '${store.pendingTaskCount}',
                  onTap: () => onNavigate(2),
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  icon: Icons.description_rounded,
                  iconColor: AppColors.violet,
                  iconBackground: AppColors.softPurple,
                  label: 'Materiais',
                  value: '${store.materials.length}',
                  onTap: () => onNavigate(4),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Próximos compromissos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigate(1),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: events.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Nenhum compromisso hoje.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : Column(
                          children: events.take(3).map((event) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      formatTime(event.start),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        Text(
                                          event.location ?? 'Sem local',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 30,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}
