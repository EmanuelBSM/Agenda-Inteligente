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
      version: 5,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async => _createSchema(database),
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(database);
        if (oldVersion < 3) await _upgradeToV3(database);
        if (oldVersion < 4) await _upgradeToV4(database);
        if (oldVersion < 5) await _upgradeToV5(database);
      },
    );
  }

  Future<void> _createSchema(sqflite.Database database) async {
    await database.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        start TEXT NOT NULL,
        end TEXT NOT NULL,
        description TEXT,
        location TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        deadline TEXT,
        deadline_has_time INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE materials_cache (
        name TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        display_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size_bytes INTEGER,
        create_time TEXT,
        uri TEXT,
        state TEXT,
        category TEXT NOT NULL DEFAULT 'Todos',
        remote INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(name, user_id),
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE chat_threads (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        previous_interaction_id TEXT,
        selected_material_names_json TEXT NOT NULL DEFAULT '[]',
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
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
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(thread_id) REFERENCES chat_threads(id) ON DELETE CASCADE
      )
    ''');
    await _createIndexes(database);
  }

  Future<void> _upgradeToV2(sqflite.Database database) async {
    // Remove os dados de demonstração que vinham na versão anterior.
    await database.delete('events', where: "id LIKE 'demo-%'");
    await database.delete('tasks', where: "id LIKE 'demo-%'");
    await database.delete('materials_cache', where: "name LIKE 'sample/%'");
    await database.delete('chat_messages', where: "id LIKE 'demo-chat-%'");

    await database.execute('''
      CREATE TABLE IF NOT EXISTS chat_threads (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        previous_interaction_id TEXT,
        selected_material_names_json TEXT NOT NULL DEFAULT '[]',
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    final columns = await database.rawQuery('PRAGMA table_info(chat_messages)');
    final names = columns.map((row) => row['name']?.toString()).toSet();
    Future<void> addColumn(String name, String type) async {
      if (!names.contains(name)) await database.execute('ALTER TABLE chat_messages ADD COLUMN $name $type');
    }

    await addColumn('thread_id', 'TEXT');
    await addColumn('task_id', 'TEXT');
    await addColumn('task_title', 'TEXT');
    await addColumn('task_deadline', 'TEXT');
    await addColumn('task_priority', 'TEXT');

    final usersWithMessages = await database.rawQuery('''
      SELECT DISTINCT user_id FROM chat_messages
      WHERE thread_id IS NULL OR thread_id = ''
    ''');
    for (final row in usersWithMessages) {
      final userId = row['user_id'] as int;
      final threadId = 'legacy-$userId';
      final now = DateTime.now().toIso8601String();
      await database.insert(
        'chat_threads',
        {
          'id': threadId,
          'user_id': userId,
          'title': 'Conversa anterior',
          'created_at': now,
          'updated_at': now,
          'previous_interaction_id': null,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
      );
      await database.update(
        'chat_messages',
        {'thread_id': threadId},
        where: 'user_id = ? AND (thread_id IS NULL OR thread_id = ?)',
        whereArgs: [userId, ''],
      );
    }
    await _createIndexes(database);
  }

  Future<void> _upgradeToV3(sqflite.Database database) async {
    final taskColumns = await database.rawQuery('PRAGMA table_info(tasks)');
    final taskNames = taskColumns.map((row) => row['name']?.toString()).toSet();
    if (!taskNames.contains('deadline_has_time')) {
      await database.execute('ALTER TABLE tasks ADD COLUMN deadline_has_time INTEGER NOT NULL DEFAULT 0');
    }

    final messageColumns = await database.rawQuery('PRAGMA table_info(chat_messages)');
    final messageNames = messageColumns.map((row) => row['name']?.toString()).toSet();
    if (!messageNames.contains('task_deadline_has_time')) {
      await database.execute('ALTER TABLE chat_messages ADD COLUMN task_deadline_has_time INTEGER');
    }
  }

  Future<void> _upgradeToV4(sqflite.Database database) async {
    final messageColumns = await database.rawQuery('PRAGMA table_info(chat_messages)');
    final messageNames = messageColumns.map((row) => row['name']?.toString()).toSet();
    if (!messageNames.contains('study_blocks_json')) {
      await database.execute('ALTER TABLE chat_messages ADD COLUMN study_blocks_json TEXT');
    }
  }

  Future<void> _upgradeToV5(sqflite.Database database) async {
    final threadColumns = await database.rawQuery('PRAGMA table_info(chat_threads)');
    final threadNames = threadColumns.map((row) => row['name']?.toString()).toSet();
    if (!threadNames.contains('selected_material_names_json')) {
      await database.execute(
        "ALTER TABLE chat_threads ADD COLUMN selected_material_names_json TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }

  Future<void> _createIndexes(sqflite.Database database) async {
    await database.execute('CREATE INDEX IF NOT EXISTS idx_events_user_start ON events(user_id, start)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_tasks_user_deadline ON tasks(user_id, deadline)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_threads_user_updated ON chat_threads(user_id, updated_at)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_messages_thread_date ON chat_messages(thread_id, created_at)');
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

  Future<List<AgendaEvent>> loadEvents(int userId) async {
    final rows = await db.query('events', where: 'user_id = ?', whereArgs: [userId], orderBy: 'start ASC');
    return rows.map(AgendaEvent.fromDbMap).toList();
  }

  Future<void> upsertEvent(int userId, AgendaEvent event) async {
    await db.insert('events', event.toDbMap(userId), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteEvent(int userId, String id) async {
    await db.delete('events', where: 'user_id = ? AND id = ?', whereArgs: [userId, id]);
  }

  Future<List<AgendaTask>> loadTasks(int userId) async {
    final rows = await db.query('tasks', where: 'user_id = ?', whereArgs: [userId], orderBy: 'deadline ASC');
    return rows.map(AgendaTask.fromDbMap).toList();
  }

  Future<void> upsertTask(int userId, AgendaTask task) async {
    await db.insert('tasks', task.toDbMap(userId), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteTask(int userId, String id) async {
    await db.delete('tasks', where: 'user_id = ? AND id = ?', whereArgs: [userId, id]);
  }

  Future<List<MaterialItem>> loadMaterials(int userId) async {
    final rows = await db.query('materials_cache', where: 'user_id = ?', whereArgs: [userId], orderBy: 'create_time DESC');
    return rows.map(MaterialItem.fromDbMap).toList();
  }

  Future<void> replaceMaterials(int userId, List<MaterialItem> items) async {
    await db.transaction((txn) async {
      await txn.delete('materials_cache', where: 'user_id = ?', whereArgs: [userId]);
      for (final item in items) {
        await txn.insert('materials_cache', item.toDbMap(userId), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> upsertMaterial(int userId, MaterialItem item) async {
    await db.insert('materials_cache', item.toDbMap(userId), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteMaterial(int userId, String name) async {
    await db.delete('materials_cache', where: 'user_id = ? AND name = ?', whereArgs: [userId, name]);
  }

  Future<List<ChatThread>> loadThreads(int userId) async {
    final rows = await db.query('chat_threads', where: 'user_id = ?', whereArgs: [userId], orderBy: 'updated_at DESC');
    return rows.map(ChatThread.fromDbMap).toList();
  }

  Future<void> upsertThread(int userId, ChatThread thread) async {
    await db.insert('chat_threads', thread.toDbMap(userId), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteThread(int userId, String threadId) async {
    await db.transaction((txn) async {
      await txn.delete('chat_messages', where: 'user_id = ? AND thread_id = ?', whereArgs: [userId, threadId]);
      await txn.delete('chat_threads', where: 'user_id = ? AND id = ?', whereArgs: [userId, threadId]);
    });
  }

  Future<List<ChatMessage>> loadMessages(int userId, String threadId) async {
    final rows = await db.query(
      'chat_messages',
      where: 'user_id = ? AND thread_id = ?',
      whereArgs: [userId, threadId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromDbMap).toList();
  }

  Future<void> upsertMessage(int userId, ChatMessage message) async {
    await db.insert('chat_messages', message.toDbMap(userId), conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> clearMessages(int userId, String threadId) async {
    await db.delete('chat_messages', where: 'user_id = ? AND thread_id = ?', whereArgs: [userId, threadId]);
  }
}
