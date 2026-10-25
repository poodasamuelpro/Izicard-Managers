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
    _database = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE offline_batches (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          client_id TEXT,
          payload_json TEXT NOT NULL,
          synced_at TEXT NOT NULL
        )
      ''');
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
          last_attempt_at TEXT
        )
      ''');
      await db.execute('CREATE INDEX pending_writes_created_idx ON pending_writes(created_at)');
    });
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Supprime les opérations et dossiers locaux avant de changer de compte.
  Future<void> clearSensitiveData() async {
    final db = await instance;
    await db.delete('pending_writes');
    await db.delete('offline_batches');
  }
}
