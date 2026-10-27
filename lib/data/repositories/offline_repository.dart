import '../local/app_database.dart';
import '../local/offline_tags_dao.dart';
import '../local/pending_writes_dao.dart';
import '../models/nfc_batch.dart';
import '../models/nfc_tag.dart';
import '../remote/tags_remote.dart';

/// Téléchargement d'un dossier pour le travail hors-ligne. L'écriture NFC lit toujours ce cache.
class OfflineRepository {
  OfflineRepository({
    required AppDatabase database,
    required TagsRemote remote,
    required this.userId,
  }) : _dao = OfflineTagsDao(database),
       _queue = PendingWritesDao(database),
       _remote = remote;

  final OfflineTagsDao _dao;
  final PendingWritesDao _queue;
  final TagsRemote _remote;
  final String userId;

  OfflineTagsDao get dao => _dao;

  /// Dossiers téléchargés, avec compteurs locaux à jour.
  Future<List<NfcBatch>> offlineBatches() async =>
      (await _dao.downloadedBatches(userId)).map((info) => info.batch).toList();

  Future<bool> hasBatch(String batchId) => _dao.hasBatch(userId, batchId);

  /// Télécharge (ou met à jour) toutes les cartes du dossier, puis ré-applique les
  /// résultats d'écriture encore en file pour ne jamais perdre un travail non synchronisé.
  Future<int> downloadBatch(NfcBatch batch) async {
    final rows = await _remote.listAllTags(batch.id);
    final tags = rows.map(NfcTagRecord.fromMap).toList();
    await _dao.saveBatch(userId: userId, batch: batch, tags: tags);
    final pending = await _queue.pending(userId, includePermanent: true);
    for (final item in pending) {
      await _dao.updateResult(
        userId: userId,
        tagId: item.tagId,
        status: item.status,
        uid: item.uid,
        locked: item.lockTag && item.status == 'verified',
      );
    }
    return tags.length;
  }

  Future<List<NfcTagRecord>> writableTags(String batchId) =>
      _dao.writableTags(userId, batchId);
}
