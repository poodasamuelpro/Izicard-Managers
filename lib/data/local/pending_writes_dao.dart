import 'app_database.dart';

class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.tagId,
    required this.status,
    required this.uid,
    required this.error,
    required this.lockTag,
    required this.attempts,
    required this.createdAt,
  });

  final int id;
  final String tagId;
  final String status;
  final String? uid;
  final String? error;
  final bool lockTag;
  final int attempts;
  final DateTime createdAt;

  factory PendingWrite.fromMap(Map<String, Object?> map) => PendingWrite(
        id: map['id']! as int,
        tagId: map['tag_id']! as String,
        status: map['status']! as String,
        uid: map['uid'] as String?,
        error: map['error'] as String?,
        lockTag: (map['lock_tag'] as int? ?? 0) == 1,
        attempts: map['attempts']! as int,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}

class PendingWritesDao {
  PendingWritesDao(this._database);
  final AppDatabase _database;

  Future<int> enqueue({
    required String tagId,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) async {
    final db = await _database.instance;
    return db.insert('pending_writes', {
      'tag_id': tagId,
      'status': status,
      'uid': uid,
      'error': error,
      'lock_tag': lockTag ? 1 : 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<PendingWrite>> pending({int limit = 50}) async {
    final db = await _database.instance;
    final rows = await db.query('pending_writes', orderBy: 'created_at ASC', limit: limit);
    return rows.map(PendingWrite.fromMap).toList();
  }

  Future<int> count() async {
    final db = await _database.instance;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM pending_writes');
    return (result.single['count']! as int);
  }

  Future<void> markAttempt(int id) async {
    final db = await _database.instance;
    await db.rawUpdate(
      'UPDATE pending_writes SET attempts = attempts + 1, last_attempt_at = ? WHERE id = ?',
      [DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  Future<void> remove(int id) async {
    final db = await _database.instance;
    await db.delete('pending_writes', where: 'id = ?', whereArgs: [id]);
  }
}
