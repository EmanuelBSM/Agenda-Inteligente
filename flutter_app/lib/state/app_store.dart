import 'package:flutter/foundation.dart';

import '../models/agenda_event.dart';
import '../models/agenda_task.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/material_item.dart';
import '../models/user_account.dart';
import '../services/local_database.dart';

class AppStore extends ChangeNotifier {
  AppStore({
    required List<AgendaEvent> events,
    required List<AgendaTask> tasks,
    required List<MaterialItem> materials,
    required List<ChatThread> threads,
    Map<String, List<ChatMessage>>? messagesByThread,
    LocalDatabase? database,
  })  : _events = events,
        _tasks = tasks,
        _materials = materials,
        _threads = threads,
        _messagesByThread = messagesByThread ?? <String, List<ChatMessage>>{},
        _database = database;

  factory AppStore.local(LocalDatabase database) => AppStore(
        events: [],
        tasks: [],
        materials: [],
        threads: [],
        database: database,
      );

  /// Mantido apenas para testes isolados. O aplicativo real não insere dados de exemplo.
  factory AppStore.empty() => AppStore(
        events: [],
        tasks: [],
        materials: [],
        threads: [],
      );

  final LocalDatabase? _database;
  UserAccount? _currentUser;
  final List<AgendaEvent> _events;
  final List<AgendaTask> _tasks;
  final List<MaterialItem> _materials;
  final List<ChatThread> _threads;
  final Map<String, List<ChatMessage>> _messagesByThread;
  final Set<Future<void>> _pendingWrites = <Future<void>>{};

  UserAccount? get currentUser => _currentUser;
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

  Future<void> loadForUser(UserAccount user) async {
    _currentUser = user;
    final database = _database;
    if (database == null) {
      notifyListeners();
      return;
    }

    _events
      ..clear()
      ..addAll(await database.loadEvents(user.id));
    _tasks
      ..clear()
      ..addAll(await database.loadTasks(user.id));
    _materials
      ..clear()
      ..addAll(await database.loadMaterials(user.id));
    _threads
      ..clear()
      ..addAll(await database.loadThreads(user.id));
    _messagesByThread.clear();
    for (final thread in _threads) {
      _messagesByThread[thread.id] = await database.loadMessages(user.id, thread.id);
    }
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    _events.clear();
    _tasks.clear();
    _materials.clear();
    _threads.clear();
    _messagesByThread.clear();
    notifyListeners();
  }

  List<AgendaEvent> eventsForDay(DateTime date) {
    final result = _events.where((event) => _sameDay(event.start.toLocal(), date)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  void addEvent(AgendaEvent event) {
    _events.add(event);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.upsertEvent(userId, event));
    }
  }

  void removeEvent(String id) {
    _events.removeWhere((event) => event.id == id);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.deleteEvent(userId, id));
    }
  }

  bool hasConflict(AgendaEvent candidate) {
    return _events.any(
      (existing) => existing.id != candidate.id && candidate.start.isBefore(existing.end) && candidate.end.isAfter(existing.start),
    );
  }

  void addTask(AgendaTask task) {
    _tasks.add(task);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.upsertTask(userId, task));
    }
  }

  void removeTask(String id) {
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.deleteTask(userId, id));
    }
  }

  void toggleTask(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(completed: !_tasks[index].completed);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.upsertTask(userId, _tasks[index]));
    }
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
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.upsertThread(userId, thread));
    }
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
      final userId = _currentUser?.id;
      if (_database != null && userId != null) {
        _queueWrite(_database!.upsertThread(userId, updated));
      }
    }

    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.upsertMessage(userId, message));
    }
  }

  void updateThreadInteraction(String threadId, String? interactionId) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) return;
    final old = _threads[index];
    final updated = interactionId == null
        ? old.copyWith(clearPreviousInteractionId: true, updatedAt: DateTime.now())
        : old.copyWith(previousInteractionId: interactionId, updatedAt: DateTime.now());
    _threads[index] = updated;
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.upsertThread(userId, updated));
    }
    notifyListeners();
  }

  Future<void> clearMessages(String threadId) async {
    _messagesByThread[threadId]?.clear();
    updateThreadInteraction(threadId, null);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      await _database!.clearMessages(userId, threadId);
    }
  }

  Future<void> deleteThread(String threadId) async {
    _threads.removeWhere((thread) => thread.id == threadId);
    _messagesByThread.remove(threadId);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      await _database!.deleteThread(userId, threadId);
    }
  }

  void replaceMaterials(List<MaterialItem> items) {
    _materials
      ..clear()
      ..addAll(items);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.replaceMaterials(userId, items));
    }
  }

  void addMaterial(MaterialItem item) {
    _materials.removeWhere((existing) => existing.name == item.name);
    _materials.insert(0, item);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.upsertMaterial(userId, item));
    }
  }

  void removeMaterial(String name) {
    _materials.removeWhere((item) => item.name == name);
    notifyListeners();
    final userId = _currentUser?.id;
    if (_database != null && userId != null) {
      _queueWrite(_database!.deleteMaterial(userId, name));
    }
  }

  void _queueWrite(Future<void> write) {
    _pendingWrites.add(write);
    write.whenComplete(() => _pendingWrites.remove(write));
  }

  Future<void> flush() async {
    if (_pendingWrites.isEmpty) return;
    await Future.wait(List<Future<void>>.from(_pendingWrites));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _deriveTitle(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 42) return clean;
    return '${clean.substring(0, 39)}...';
  }
}
