import 'package:flutter/material.dart';

import '../models/agenda_event.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.store});

  final AppStore store;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime visibleMonth;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    visibleMonth = DateTime(now.year, now.month, 1);
    selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final events = widget.store.eventsForDay(selectedDate);
        return SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Calendário',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1, 1);
                          }),
                          icon: const Icon(Icons.chevron_left_rounded, size: 32),
                        ),
                        Expanded(
                          child: Text(
                            formatMonthYear(visibleMonth),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 1);
                          }),
                          icon: const Icon(Icons.chevron_right_rounded, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _WeekdayHeader(),
                    const SizedBox(height: 6),
                    _MonthGrid(
                      visibleMonth: visibleMonth,
                      selectedDate: selectedDate,
                      onSelected: (date) => setState(() => selectedDate = date),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      formatLongDate(selectedDate),
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 14),
                    if (events.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.softBlue,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text('Nenhum compromisso para este dia.'),
                      )
                    else
                      ...events.map((event) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EventCard(event: event),
                          )),
                  ],
                ),
              ),
              Positioned(
                right: 22,
                bottom: 20,
                child: FloatingActionButton(
                  heroTag: 'calendar-add',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: _showAddEvent,
                  child: const Icon(Icons.add_rounded, size: 34),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddEvent() async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 15, minute: 0);

    final created = await showModalBottomSheet<AgendaEvent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Novo evento', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Título')),
                  const SizedBox(height: 12),
                  TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Local (opcional)')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showTimePicker(context: context, initialTime: startTime);
                            if (value != null) setModalState(() => startTime = value);
                          },
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text('Início ${startTime.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showTimePicker(context: context, initialTime: endTime);
                            if (value != null) setModalState(() => endTime = value);
                          },
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text('Fim ${endTime.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;
                        final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
                        final end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);
                        if (!end.isAfter(start)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O horário final deve ser depois do início.')));
                          return;
                        }
                        Navigator.pop(
                          context,
                          AgendaEvent(
                            id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
                            title: title,
                            start: start,
                            end: end,
                            location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Criar evento'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    locationController.dispose();

    if (created == null || !mounted) return;
    if (widget.store.hasConflict(created)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Conflito de horário'),
          content: const Text('Já existe um compromisso nesse horário. Deseja criar mesmo assim?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Criar mesmo assim')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    widget.store.addEvent(created);
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Row(
      children: days.map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))).toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.visibleMonth, required this.selectedDate, required this.onSelected});

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final sundayIndex = first.weekday % 7;
    final gridStart = first.subtract(Duration(days: sundayIndex));
    final dates = List.generate(42, (index) => gridStart.add(Duration(days: index)));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.05),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final inMonth = date.month == visibleMonth.month;
        final selected = date.year == selectedDate.year && date.month == selectedDate.month && date.day == selectedDate.day;
        return InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => onSelected(date),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: selected ? const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle) : null,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: selected ? Colors.white : (inMonth ? AppColors.ink : AppColors.muted),
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final AgendaEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 13, color: AppColors.primary),
          const SizedBox(width: 13),
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatTime(event.start), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                Text(formatTime(event.end), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
              ],
            ),
          ),
          const VerticalDivider(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                if (event.location != null) Text(event.location!, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
