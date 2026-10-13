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
                            child: _EventCard(
                              event: event,
                              onEdit: () => _showEventForm(existing: event),
                              onDelete: () => _confirmDeleteEvent(event),
                            ),
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

  Future<void> _showAddEvent() => _showEventForm();

  Future<void> _showEventForm({AgendaEvent? existing}) async {
    final initialDate = existing?.start ?? selectedDate;
    final result = await showModalBottomSheet<AgendaEvent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EventFormSheet(initialDate: initialDate, initialEvent: existing),
    );

    if (result == null || !mounted) return;

    if (widget.store.hasConflict(result)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Conflito de horário'),
          content: const Text('Já existe um compromisso nesse horário. Deseja salvar mesmo assim?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar mesmo assim'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    if (existing == null) {
      widget.store.addEvent(result);
    } else {
      widget.store.updateEvent(result);
    }

    setState(() {
      selectedDate = DateTime(result.start.year, result.start.month, result.start.day);
      visibleMonth = DateTime(result.start.year, result.start.month, 1);
    });
  }

  Future<void> _confirmDeleteEvent(AgendaEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Excluir evento?'),
        content: Text('O evento "${event.title}" será removido permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('confirm-delete-event'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) widget.store.removeEvent(event.id);
  }
}

class _EventFormSheet extends StatefulWidget {
  const _EventFormSheet({required this.initialDate, this.initialEvent});

  final DateTime initialDate;
  final AgendaEvent? initialEvent;

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  late final TextEditingController titleController;
  late final TextEditingController locationController;
  late final TextEditingController descriptionController;
  late DateTime eventDate;
  late TimeOfDay startTime;
  late TimeOfDay endTime;

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    titleController = TextEditingController(text: event?.title ?? '');
    locationController = TextEditingController(text: event?.location ?? '');
    descriptionController = TextEditingController(text: event?.description ?? '');
    final date = event?.start ?? widget.initialDate;
    eventDate = DateTime(date.year, date.month, date.day);
    startTime = event == null ? const TimeOfDay(hour: 14, minute: 0) : TimeOfDay.fromDateTime(event.start);
    endTime = event == null ? const TimeOfDay(hour: 15, minute: 0) : TimeOfDay.fromDateTime(event.end);
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDate: eventDate.isBefore(DateTime(1900)) ? DateTime(1900) : eventDate,
    );
    if (!mounted || value == null) return;
    setState(() => eventDate = DateTime(value.year, value.month, value.day));
  }

  Future<void> _pickStartTime() async {
    final value = await showTimePicker(context: context, initialTime: startTime);
    if (!mounted || value == null) return;
    setState(() => startTime = value);
  }

  Future<void> _pickEndTime() async {
    final value = await showTimePicker(context: context, initialTime: endTime);
    if (!mounted || value == null) return;
    setState(() => endTime = value);
  }

  void _saveEvent() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o título do evento.')));
      return;
    }

    final start = DateTime(eventDate.year, eventDate.month, eventDate.day, startTime.hour, startTime.minute);
    final end = DateTime(eventDate.year, eventDate.month, eventDate.day, endTime.hour, endTime.minute);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O horário final deve ser depois do início.')));
      return;
    }

    FocusScope.of(context).unfocus();
    final existing = widget.initialEvent;
    final location = locationController.text.trim();
    final description = descriptionController.text.trim();
    Navigator.of(context).pop(
      AgendaEvent(
        id: existing?.id ?? 'manual-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        start: start,
        end: end,
        location: location.isEmpty ? null : location,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialEvent != null;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: true,
      bottom: true,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 20, 20, keyboardInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(editing ? 'Editar evento' : 'Novo evento', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextField(
              key: const Key('event-title-input'),
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Local (opcional)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('event-date-input'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text('Data: ${formatShortDate(eventDate)}'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text('Início ${startTime.format(context)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEndTime,
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
                key: const Key('event-save'),
                onPressed: _saveEvent,
                child: Text(editing ? 'Salvar alterações' : 'Criar evento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Row(
      children: days.map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink))))).toList(),
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
  const _EventCard({required this.event, required this.onEdit, required this.onDelete});

  final AgendaEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 13, color: AppColors.primary),
          ),
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
          const SizedBox(width: 12),
          Container(width: 1, height: 54, color: AppColors.border),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                if (event.location != null) Text(event.location!, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                if (event.description != null && event.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(event.description!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: Key('event-actions-${event.id}'),
            tooltip: 'Ações do evento',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
    );
  }
}
