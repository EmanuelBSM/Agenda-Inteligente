import 'package:flutter/material.dart';

import '../models/agenda_task.dart';
import '../state/app_store.dart';
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
                        const Expanded(child: Text('Tarefas', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800))),
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
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(14)),
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
                              selectedColor: const Color(0xFF3D3D3D),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                              side: const BorderSide(color: Color(0xFFDADADA)),
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
                  backgroundColor: const Color(0xFF3A3A3A),
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
    final titleController = TextEditingController();
    final now = DateTime.now();
    DateTime? deadline = DateTime(now.year, now.month, now.day);
    bool deadlineHasTime = false;
    TimeOfDay? deadlineTime;
    TaskPriority priority = TaskPriority.media;

    final task = await showModalBottomSheet<AgendaTask>(
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
                  const Text('Nova tarefa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Título')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              initialDate: deadline ?? DateTime.now(),
                            );
                            if (value != null) {
                              setModalState(() {
                                if (deadlineHasTime && deadlineTime != null) {
                                  deadline = DateTime(value.year, value.month, value.day, deadlineTime!.hour, deadlineTime!.minute);
                                } else {
                                  deadline = DateTime(value.year, value.month, value.day);
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(deadline == null ? 'Sem prazo' : formatShortDate(deadline!)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: deadline == null
                              ? null
                              : () async {
                                  final value = await showTimePicker(
                                    context: context,
                                    initialTime: deadlineTime ?? TimeOfDay.fromDateTime(DateTime.now()),
                                  );
                                  if (value != null) {
                                    setModalState(() {
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
                                },
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(deadlineHasTime && deadline != null ? formatTime(deadline!) : 'Horário'),
                        ),
                      ),
                    ],
                  ),
                  if (deadlineHasTime) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            deadlineHasTime = false;
                            deadlineTime = null;
                            if (deadline != null) {
                              deadline = DateTime(deadline!.year, deadline!.month, deadline!.day);
                            }
                          });
                        },
                        child: const Text('Remover horário'),
                      ),
                    ),
                  ],
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
                          if (value != null) setModalState(() => priority = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) return;
                        Navigator.pop(
                          context,
                          AgendaTask(
                            id: 'task-${DateTime.now().microsecondsSinceEpoch}',
                            title: titleController.text.trim(),
                            deadline: deadline,
                            deadlineHasTime: deadlineHasTime,
                            priority: priority,
                          ),
                        );
                      },
                      child: const Text('Criar tarefa'),
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
    if (task != null) widget.store.addTask(task);
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
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.completed,
            onChanged: (_) => onToggle(),
            activeColor: const Color(0xFF444444),
            side: const BorderSide(color: Color(0xFF555555), width: 1.5),
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
                    color: task.completed ? const Color(0xFF777777) : Colors.black,
                  ),
                ),
                if (task.deadline != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF777777)),
                      const SizedBox(width: 5),
                      Text(
                        task.deadlineHasTime
                            ? '${formatShortDate(task.deadline!)} • ${formatTime(task.deadline!)}'
                            : formatShortDate(task.deadline!),
                        style: const TextStyle(color: Color(0xFF777777)),
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
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(16)),
            child: Text(_priorityLabel(task.priority), style: const TextStyle(fontWeight: FontWeight.w600)),
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
