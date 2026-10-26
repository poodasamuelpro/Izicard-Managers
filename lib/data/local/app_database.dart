import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({String? databaseName}) : _databaseName = databaseName ?? 'izicard_offline.db';

  final String _databaseName;
  Database? _database;

  Future<Database> get instance async {
    final existing = _database;
    if (existing != null) return existing;
    final path = p.join(await getDatabasesPath(), _databaseName);
    _database = await openDatabase(path, version: 3, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE offline_batches (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          client_id TEXT,
          payload_json TEXT NOT NULL,
          synced_at TEXT NOT NULL,
          user_id TEXT
        )
      ''');
      await _createPendingWrites(db);
      await _createCachedProfiles(db);
      await _createOfflineTags(db);
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await _createCachedProfiles(db);
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE pending_writes ADD COLUMN user_id TEXT');
        await db.execute('ALTER TABLE pending_writes ADD COLUMN permanent INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE pending_writes ADD COLUMN sync_error TEXT');
        await db.execute('ALTER TABLE offline_batches ADD COLUMN user_id TEXT');
        await _createOfflineTags(db);
      }
    });
    return _database!;
  }

  static Future<void> _createPendingWrites(Database db) async {
    await db.execute('''
      CREATE TABLE pending_writes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tag_id TEXT NOT NULL,
        status TEXT NOT NULL,
        uid TEXT,
        error TEXT,
        lock_tag INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_attempt_at TEXT,
        user_id TEXT,
        permanent INTEGER NOT NULL DEFAULT 0,
        sync_error TEXT
      )
    ''');
    await db.execute('CREATE INDEX pending_writes_created_idx ON pending_writes(created_at)');
  }

  static Future<void> _createCachedProfiles(Database db) async {
    await db.execute('''
      CREATE TABLE cached_profiles (
        user_id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createOfflineTags(Database db) async {
    await db.execute('''
      CREATE TABLE offline_tags (
        user_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        batch_id TEXT NOT NULL,
        seq INTEGER NOT NULL,
        public_id TEXT NOT NULL,
        data_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        fields_json TEXT NOT NULL,
        status TEXT NOT NULL,
        uid TEXT,
        locked INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT NOT NULL,
        PRIMARY KEY (user_id, tag_id)
      )
    ''');
    await db.execute('CREATE INDEX offline_tags_batch_idx ON offline_tags(user_id, batch_id, seq)');
    await db.execute('CREATE INDEX offline_tags_uid_idx ON offline_tags(user_id, uid)');
  }

  Future<void> cacheProfile({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await instance;
    await db.insert(
      'cached_profiles',
      {
        'user_id': userId,
        'payload_json': jsonEncode(payload),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> readCachedProfile(
    String userId, {
    Duration maxAge = const Duration(days: 31),
  }) async {
    final db = await instance;
    final rows = await db.query(
      'cached_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final cachedAt = DateTime.tryParse(row['cached_at'] as String)?.toUtc();
    if (cachedAt == null || DateTime.now().toUtc().difference(cachedAt) > maxAge) {
      await db.delete('cached_profiles', where: 'user_id = ?', whereArgs: [userId]);
      return null;
    }
    final decoded = jsonDecode(row['payload_json'] as String);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<void> deleteCachedProfile(String userId) async {
    final db = await instance;
    await db.delete('cached_profiles', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
