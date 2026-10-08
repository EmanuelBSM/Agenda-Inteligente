import 'package:flutter/material.dart';

import '../models/agenda_task.dart';
import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key, required this.store});

  final AppStore store;

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  final searchController = TextEditingController();
  String filter = 'Todas';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final query = searchController.text.trim().toLowerCase();
        final tasks = widget.store.tasks.where((task) {
          final matchesQuery = query.isEmpty || task.title.toLowerCase().contains(query);
          final matchesFilter = switch (filter) {
            'Alta' => task.priority == TaskPriority.alta,
            'Média' => task.priority == TaskPriority.media,
            'Baixa' => task.priority == TaskPriority.baixa,
            _ => true,
          };
          return matchesQuery && matchesFilter;
        }).toList();

        return SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Tarefas', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800, color: AppColors.ink))),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded, size: 28)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar tarefas...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: ['Todas', 'Alta', 'Média', 'Baixa'].map((label) {
                        final selected = filter == label;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: SizedBox(width: double.infinity, child: Text(label, textAlign: TextAlign.center)),
                              selected: selected,
                              onSelected: (_) => setState(() => filter = label),
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    ...tasks.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TaskCard(task: task, onToggle: () => widget.store.toggleTask(task.id)),
                        )),
                    if (tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text('Nenhuma tarefa encontrada.')),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 22,
                bottom: 20,
                child: FloatingActionButton(
                  heroTag: 'tasks-add',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: _showAddTask,
                  child: const Icon(Icons.add_rounded, size: 34),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddTask() async {
    final task = await showModalBottomSheet<AgendaTask>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _TaskFormSheet(),
    );

    if (task != null && mounted) {
      widget.store.addTask(task);
    }
  }

}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet();

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  final titleController = TextEditingController();

  late DateTime? deadline;
  bool deadlineHasTime = false;
  TimeOfDay? deadlineTime;
  TaskPriority priority = TaskPriority.media;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    deadline = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: deadline ?? DateTime.now(),
    );
    if (!mounted || value == null) return;

    setState(() {
      if (deadlineHasTime && deadlineTime != null) {
        deadline = DateTime(
          value.year,
          value.month,
          value.day,
          deadlineTime!.hour,
          deadlineTime!.minute,
        );
      } else {
        deadline = DateTime(value.year, value.month, value.day);
      }
    });
  }

  Future<void> _pickTime() async {
    if (deadline == null) return;

    final value = await showTimePicker(
      context: context,
      initialTime: deadlineTime ?? TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (!mounted || value == null) return;

    setState(() {
      deadlineTime = value;
      deadlineHasTime = true;
      deadline = DateTime(
        deadline!.year,
        deadline!.month,
        deadline!.day,
        value.hour,
        value.minute,
      );
    });
  }

  void _removeTime() {
    setState(() {
      deadlineHasTime = false;
      deadlineTime = null;
      if (deadline != null) {
        deadline = DateTime(deadline!.year, deadline!.month, deadline!.day);
      }
    });
  }

  void _createTask() {
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      AgendaTask(
        id: 'task-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        deadline: deadline,
        deadlineHasTime: deadlineHasTime,
        priority: priority,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, keyboardInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nova tarefa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Título'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createTask(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(deadline == null ? 'Sem prazo' : formatShortDate(deadline!)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: deadline == null ? null : _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(deadlineHasTime && deadline != null ? formatTime(deadline!) : 'Horário'),
                ),
              ),
            ],
          ),
          if (deadlineHasTime)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _removeTime,
                child: const Text('Remover horário'),
              ),
            ),
          Row(
            children: [
              const Text('Prioridade:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<TaskPriority>(
                value: priority,
                items: TaskPriority.values
                    .map((value) => DropdownMenuItem(value: value, child: Text(_priorityLabel(value))))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => priority = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _createTask,
              child: const Text('Criar tarefa'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onToggle});

  final AgendaTask task;
  final VoidCallback onToggle;

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
          Checkbox(
            value: task.completed,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.success,
            side: const BorderSide(color: AppColors.muted, width: 1.5),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                    color: task.completed ? AppColors.muted : AppColors.ink,
                  ),
                ),
                if (task.deadline != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        task.deadlineHasTime
                            ? '${formatShortDate(task.deadline!)} • ${formatTime(task.deadline!)}'
                            : formatShortDate(task.deadline!),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _priorityBackground(task.priority),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _priorityLabel(task.priority),
              style: TextStyle(fontWeight: FontWeight.w700, color: _priorityColor(task.priority)),
            ),
          ),
        ],
      ),
    );
  }
}

String _priorityLabel(TaskPriority value) => switch (value) {
      TaskPriority.alta => 'Alta',
      TaskPriority.media => 'Média',
      TaskPriority.baixa => 'Baixa',
    };

Color _priorityColor(TaskPriority value) => switch (value) {
      TaskPriority.alta => AppColors.danger,
      TaskPriority.media => const Color(0xFF9A6200),
      TaskPriority.baixa => const Color(0xFF168A46),
    };

Color _priorityBackground(TaskPriority value) => switch (value) {
      TaskPriority.alta => const Color(0xFFFFE8EA),
      TaskPriority.media => const Color(0xFFFFF0CF),
      TaskPriority.baixa => AppColors.softGreen,
    };
