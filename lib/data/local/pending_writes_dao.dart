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
    required this.userId,
    required this.permanent,
    required this.syncError,
  });

  final int id;
  final String tagId;
  final String status;
  final String? uid;
  final String? error;
  final bool lockTag;
  final int attempts;
  final DateTime createdAt;
  final String? userId;

  /// Refus définitif de la base (UID déjà utilisé, carte annulée, accès refusé…).
  final bool permanent;
  final String? syncError;

  factory PendingWrite.fromMap(Map<String, Object?> map) => PendingWrite(
        id: map['id']! as int,
        tagId: map['tag_id']! as String,
        status: map['status']! as String,
        uid: map['uid'] as String?,
        error: map['error'] as String?,
        lockTag: (map['lock_tag'] as int? ?? 0) == 1,
        attempts: map['attempts']! as int,
        createdAt: DateTime.parse(map['created_at']! as String),
        userId: map['user_id'] as String?,
        permanent: (map['permanent'] as int? ?? 0) == 1,
        syncError: map['sync_error'] as String?,
      );
}

/// File d'envoi locale, cloisonnée par utilisateur : un élément n'est jamais
/// envoyé sous la session d'un autre compte.
class PendingWritesDao {
  PendingWritesDao(this._database);
  final AppDatabase _database;

  Future<int> enqueue({
    required String userId,
    required String tagId,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) async {
    final db = await _database.instance;
    return db.insert('pending_writes', {
      'user_id': userId,
      'tag_id': tagId,
      'status': status,
      'uid': uid,
      'error': error,
      'lock_tag': lockTag ? 1 : 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Éléments de [userId]. Par défaut, uniquement ceux qui peuvent encore partir.
  Future<List<PendingWrite>> pending(String userId, {int limit = 200, bool includePermanent = false}) async {
    final db = await _database.instance;
    final rows = await db.query(
      'pending_writes',
      where: includePermanent ? 'user_id = ?' : 'user_id = ? AND permanent = 0',
      whereArgs: [userId],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    return rows.map(PendingWrite.fromMap).toList();
  }

  Future<int> count(String userId, {bool includePermanent = true}) async {
    final db = await _database.instance;
    final result = await db.rawQuery(
      includePermanent
          ? 'SELECT COUNT(*) AS count FROM pending_writes WHERE user_id = ?'
          : 'SELECT COUNT(*) AS count FROM pending_writes WHERE user_id = ? AND permanent = 0',
      [userId],
    );
    return result.single['count']! as int;
  }

  Future<void> markAttempt(int id) async {
    final db = await _database.instance;
    await db.rawUpdate(
      'UPDATE pending_writes SET attempts = attempts + 1, last_attempt_at = ? WHERE id = ?',
      [DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  Future<void> markPermanent(int id, String message) async {
    final db = await _database.instance;
    await db.update('pending_writes', {'permanent': 1, 'sync_error': message}, where: 'id = ?', whereArgs: [id]);
  }

  /// Remet un élément refusé dans la file normale (ex. après correction côté admin).
  Future<void> retry(int id) async {
    final db = await _database.instance;
    await db.update('pending_writes', {'permanent': 0, 'sync_error': null}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> remove(int id) async {
    final db = await _database.instance;
    await db.delete('pending_writes', where: 'id = ?', whereArgs: [id]);
  }
}
