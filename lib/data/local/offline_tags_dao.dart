import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/nfc_batch.dart';
import '../models/nfc_tag.dart';
import 'app_database.dart';

class OfflineBatchInfo {
  const OfflineBatchInfo({required this.batch, required this.syncedAt, required this.tagCount});
  final NfcBatch batch;
  final DateTime syncedAt;
  final int tagCount;
}

/// Cache local des dossiers et cartes téléchargés, cloisonné par utilisateur.
/// L'écriture NFC lit toujours ce cache.
class OfflineTagsDao {
  OfflineTagsDao(this._database);
  final AppDatabase _database;

  static String _batchKey(String userId, String batchId) => '$userId|$batchId';

  Future<void> saveBatch({
    required String userId,
    required NfcBatch batch,
    required List<NfcTagRecord> tags,
  }) async {
    final db = await _database.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('offline_tags', where: 'user_id = ? AND batch_id = ?', whereArgs: [userId, batch.id]);
      final batchRow = {
        'id': _batchKey(userId, batch.id),
        'name': batch.name,
        'client_id': batch.clientId,
        'user_id': userId,
        'synced_at': now,
        'payload_json': jsonEncode({
          'batch_id': batch.id,
          'client_id': batch.clientId,
          'name': batch.name,
          'status': batch.status,
          'quantity': batch.quantity,
          'total': batch.total,
          'pending': batch.pending,
          'written': batch.written,
          'verified': batch.verified,
          'error': batch.errors,
          'void': batch.voided,
        }),
      };
      await txn.insert('offline_batches', batchRow, conflictAlgorithm: ConflictAlgorithm.replace);
      final b = txn.batch();
      for (final tag in tags) {
        b.insert(
          'offline_tags',
          {
            'user_id': userId,
            'tag_id': tag.id,
            'batch_id': tag.batchId,
            'seq': tag.sequence,
            'public_id': tag.publicId,
            'data_type': tag.dataType,
            'payload': tag.payload,
            'fields_json': jsonEncode(tag.fields),
            'status': tag.status,
            'uid': tag.uid,
            'locked': tag.locked ? 1 : 0,
            'synced_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await b.commit(noResult: true);
    });
  }

  Future<List<OfflineBatchInfo>> downloadedBatches(String userId) async {
    final db = await _database.instance;
    final rows = await db.query('offline_batches', where: 'user_id = ?', whereArgs: [userId], orderBy: 'name ASC');
    final infos = <OfflineBatchInfo>[];
    for (final row in rows) {
      final decoded = jsonDecode(row['payload_json']! as String);
      if (decoded is! Map) continue;
      final batch = NfcBatch.fromStats(Map<String, dynamic>.from(decoded));
      final count = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM offline_tags WHERE user_id = ? AND batch_id = ?',
            [userId, batch.id],
          )) ??
          0;
      infos.add(OfflineBatchInfo(
        batch: batch,
        syncedAt: DateTime.tryParse(row['synced_at']! as String) ?? DateTime.now(),
        tagCount: count,
      ));
    }
    return infos;
  }

  Future<bool> hasBatch(String userId, String batchId) async {
    final db = await _database.instance;
    final rows = await db.query('offline_batches',
        where: 'id = ?', whereArgs: [_batchKey(userId, batchId)], limit: 1);
    return rows.isNotEmpty;
  }

  Future<List<NfcTagRecord>> writableTags(String userId, String batchId) async {
    final db = await _database.instance;
    final rows = await db.query(
      'offline_tags',
      where: "user_id = ? AND batch_id = ? AND status IN ('pending','error') AND locked = 0",
      whereArgs: [userId, batchId],
      orderBy: 'seq ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<NfcTagRecord?> findByUid(String userId, String uid) async {
    final db = await _database.instance;
    final rows = await db.query(
      'offline_tags',
      where: "user_id = ? AND uid = ? AND status <> 'void'",
      whereArgs: [userId, uid],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> updateResult({
    required String userId,
    required String tagId,
    required String status,
    String? uid,
    bool locked = false,
  }) async {
    final db = await _database.instance;
    await db.rawUpdate(
      'UPDATE offline_tags SET status = ?, uid = COALESCE(?, uid), locked = ? WHERE user_id = ? AND tag_id = ?',
      [status, uid, locked ? 1 : 0, userId, tagId],
    );
  }

  Future<void> removeBatch(String userId, String batchId) async {
    final db = await _database.instance;
    await db.transaction((txn) async {
      await txn.delete('offline_tags', where: 'user_id = ? AND batch_id = ?', whereArgs: [userId, batchId]);
      await txn.delete('offline_batches', where: 'id = ?', whereArgs: [_batchKey(userId, batchId)]);
    });
  }

  NfcTagRecord _fromRow(Map<String, Object?> row) {
    final fields = jsonDecode(row['fields_json']! as String);
    return NfcTagRecord(
      id: row['tag_id']! as String,
      batchId: row['batch_id']! as String,
      sequence: row['seq']! as int,
      publicId: row['public_id']! as String,
      dataType: row['data_type']! as String,
      payload: row['payload']! as String,
      fields: fields is Map ? Map<String, dynamic>.from(fields) : const {},
      status: row['status']! as String,
      uid: row['uid'] as String?,
      locked: (row['locked'] as int? ?? 0) == 1,
    );
  }
}
