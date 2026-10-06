import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../models/agenda_event.dart';
import '../models/agenda_task.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/material_item.dart';

class LocalDatabase {
  LocalDatabase({this.inMemory = false});

  final bool inMemory;
  sqflite.Database? _database;

  sqflite.Database get db {
    final value = _database;
    if (value == null) throw StateError('Banco local ainda não foi inicializado.');
    return value;
  }

  Future<void> initialize() async {
    if (_database != null) return;

    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      sqflite.databaseFactory = ffi.databaseFactoryFfi;
    }

    final path = inMemory ? sqflite.inMemoryDatabasePath : await _databasePath();
    _database = await sqflite.openDatabase(
      path,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createChatSchema(database);
      },
    );
  }

  Future<void> _createSchema(sqflite.Database database, int version) async {
    await database.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        start TEXT NOT NULL,
        end TEXT NOT NULL,
        description TEXT,
        location TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        deadline TEXT,
        deadline_has_time INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE materials_cache (
        name TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size_bytes INTEGER,
        create_time TEXT,
        uri TEXT,
        state TEXT,
        category TEXT NOT NULL DEFAULT 'Todos',
        remote INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('CREATE INDEX idx_events_start ON events(start)');
    await database.execute('CREATE INDEX idx_tasks_deadline ON tasks(deadline)');
    await _createChatSchema(database);
  }

  Future<void> _createChatSchema(sqflite.Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS chat_threads (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        previous_interaction_id TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        thread_id TEXT NOT NULL,
        text TEXT NOT NULL,
        from_user INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        event_id TEXT,
        event_title TEXT,
        event_start TEXT,
        event_end TEXT,
        event_description TEXT,
        event_location TEXT,
        task_id TEXT,
        task_title TEXT,
        task_deadline TEXT,
        task_deadline_has_time INTEGER,
        task_priority TEXT,
        study_blocks_json TEXT,
        FOREIGN KEY(thread_id) REFERENCES chat_threads(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_threads_updated ON chat_threads(updated_at)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_thread_date ON chat_messages(thread_id, created_at)',
    );
  }

  Future<String> _databasePath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      return p.join(directory.path, 'agenda_inteligente.db');
    }
    return p.join(await sqflite.getDatabasesPath(), 'agenda_inteligente.db');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<List<AgendaEvent>> loadEvents() async {
    final rows = await db.query('events', orderBy: 'start ASC');
    return rows.map(AgendaEvent.fromDbMap).toList();
  }

  Future<void> upsertEvent(AgendaEvent event) async {
    await db.insert('events', event.toDbMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteEvent(String id) async {
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AgendaTask>> loadTasks() async {
    final rows = await db.query('tasks', orderBy: 'deadline ASC');
    return rows.map(AgendaTask.fromDbMap).toList();
  }

  Future<void> upsertTask(AgendaTask task) async {
    await db.insert('tasks', task.toDbMap(), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteTask(String id) async {
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MaterialItem>> loadMaterials() async {
    final rows = await db.query('materials_cache', orderBy: 'create_time DESC');
    return rows.map(MaterialItem.fromDbMap).toList();
  }

  Future<void> replaceMaterials(List<MaterialItem> items) async {
    await db.transaction((txn) async {
      await txn.delete('materials_cache');
      for (final item in items) {
        await txn.insert(
          'materials_cache',
          item.toDbMap(),
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertMaterial(MaterialItem item) async {
    await db.insert(
      'materials_cache',
      item.toDbMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMaterial(String name) async {
    await db.delete('materials_cache', where: 'name = ?', whereArgs: [name]);
  }

  Future<List<ChatThread>> loadThreads() async {
    final rows = await db.query('chat_threads', orderBy: 'updated_at DESC');
    return rows.map(ChatThread.fromDbMap).toList();
  }

  Future<void> upsertThread(ChatThread thread) async {
    await db.insert(
      'chat_threads',
      thread.toDbMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteThread(String threadId) async {
    await db.delete('chat_threads', where: 'id = ?', whereArgs: [threadId]);
  }

  Future<List<ChatMessage>> loadMessages(String threadId) async {
    final rows = await db.query(
      'chat_messages',
      where: 'thread_id = ?',
      whereArgs: [threadId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromDbMap).toList();
  }

  Future<void> upsertMessage(ChatMessage message) async {
    await db.insert(
      'chat_messages',
      message.toDbMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> clearMessages(String threadId) async {
    await db.delete('chat_messages', where: 'thread_id = ?', whereArgs: [threadId]);
  }
}
