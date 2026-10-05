import 'package:flutter/foundation.dart';

import '../models/agenda_event.dart';
import '../models/agenda_task.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/material_item.dart';

/// Estado somente em memória.
///
/// Nada desta classe é persistido. Ao fechar o aplicativo, eventos, tarefas,
/// materiais e conversas desaparecem.
class AppStore extends ChangeNotifier {
  AppStore({
    required List<AgendaEvent> events,
    required List<AgendaTask> tasks,
    required List<MaterialItem> materials,
    required List<ChatThread> threads,
    Map<String, List<ChatMessage>>? messagesByThread,
  })  : _events = events,
        _tasks = tasks,
        _materials = materials,
        _threads = threads,
        _messagesByThread = messagesByThread ?? <String, List<ChatMessage>>{};

  factory AppStore.memory() => AppStore(
        events: <AgendaEvent>[],
        tasks: <AgendaTask>[],
        materials: <MaterialItem>[],
        threads: <ChatThread>[],
      );

  factory AppStore.empty() => AppStore.memory();

  final List<AgendaEvent> _events;
  final List<AgendaTask> _tasks;
  final List<MaterialItem> _materials;
  final List<ChatThread> _threads;
  final Map<String, List<ChatMessage>> _messagesByThread;

  List<AgendaEvent> get events => List.unmodifiable(_events);
  List<AgendaTask> get tasks => List.unmodifiable(_tasks);
  List<MaterialItem> get materials => List.unmodifiable(_materials);
  List<ChatThread> get threads => List.unmodifiable(_threads);
  int get pendingTaskCount => _tasks.where((task) => !task.completed).length;

  List<ChatMessage> messagesForThread(String threadId) =>
      List.unmodifiable(_messagesByThread[threadId] ?? const <ChatMessage>[]);

  ChatThread? threadById(String threadId) {
    for (final thread in _threads) {
      if (thread.id == threadId) return thread;
    }
    return null;
  }

  List<AgendaEvent> eventsForDay(DateTime date) {
    final result = _events.where((event) => _sameDay(event.start.toLocal(), date)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  void addEvent(AgendaEvent event) {
    _events.add(event);
    notifyListeners();
  }

  void removeEvent(String id) {
    _events.removeWhere((event) => event.id == id);
    notifyListeners();
  }

  bool hasConflict(AgendaEvent candidate) {
    return _events.any(
      (existing) => existing.id != candidate.id && candidate.start.isBefore(existing.end) && candidate.end.isAfter(existing.start),
    );
  }

  void addTask(AgendaTask task) {
    _tasks.add(task);
    notifyListeners();
  }

  void removeTask(String id) {
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
  }

  void toggleTask(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(completed: !_tasks[index].completed);
    notifyListeners();
  }

  ChatThread createThread({String title = 'Nova conversa'}) {
    final now = DateTime.now();
    final thread = ChatThread(
      id: 'thread-${now.microsecondsSinceEpoch}',
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    _threads.insert(0, thread);
    _messagesByThread[thread.id] = <ChatMessage>[];
    notifyListeners();
    return thread;
  }

  void addMessage(ChatMessage message) {
    final list = _messagesByThread.putIfAbsent(message.threadId, () => <ChatMessage>[]);
    list.add(message);

    final threadIndex = _threads.indexWhere((thread) => thread.id == message.threadId);
    if (threadIndex >= 0) {
      final old = _threads[threadIndex];
      final firstUserMessage = message.fromUser && list.where((item) => item.fromUser).length == 1;
      final updated = old.copyWith(
        title: firstUserMessage && old.title == 'Nova conversa' ? _deriveTitle(message.text) : old.title,
        updatedAt: message.createdAt,
      );
      _threads
        ..removeAt(threadIndex)
        ..insert(0, updated);
    }
    notifyListeners();
  }

  void updateThreadInteraction(String threadId, String? interactionId) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) return;
    final old = _threads[index];
    _threads[index] = interactionId == null
        ? old.copyWith(clearPreviousInteractionId: true, updatedAt: DateTime.now())
        : old.copyWith(previousInteractionId: interactionId, updatedAt: DateTime.now());
    notifyListeners();
  }

  Future<void> clearMessages(String threadId) async {
    _messagesByThread[threadId]?.clear();
    updateThreadInteraction(threadId, null);
    notifyListeners();
  }

  Future<void> deleteThread(String threadId) async {
    _threads.removeWhere((thread) => thread.id == threadId);
    _messagesByThread.remove(threadId);
    notifyListeners();
  }

  void replaceMaterials(List<MaterialItem> items) {
    _materials
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  void addMaterial(MaterialItem item) {
    _materials.removeWhere((existing) => existing.name == item.name);
    _materials.insert(0, item);
    notifyListeners();
  }

  void removeMaterial(String name) {
    _materials.removeWhere((item) => item.name == name);
    notifyListeners();
  }

  void clearSession() {
    _events.clear();
    _tasks.clear();
    _materials.clear();
    _threads.clear();
    _messagesByThread.clear();
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _deriveTitle(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 42) return clean;
    return '${clean.substring(0, 39)}...';
  }
}
