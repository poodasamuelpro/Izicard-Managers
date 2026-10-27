import '../local/app_database.dart';
import '../local/offline_tags_dao.dart';
import '../models/nfc_tag.dart';
import '../remote/tags_remote.dart';
import 'sync_repository.dart';

/// Garde-fous avant écriture et enregistrement du résultat (local d'abord, puis envoi).
/// Partagé par la série d'écriture et l'écriture d'une seule carte.
class WriteRecorder {
  WriteRecorder({
    required AppDatabase database,
    required TagsRemote remote,
    required this.userId,
  }) : _offline = OfflineTagsDao(database),
       _remote = remote,
       _sync = SyncRepository(
         database: database,
         remote: remote,
         userId: userId,
       );

  final String userId;
  final OfflineTagsDao _offline;
  final TagsRemote _remote;
  final SyncRepository _sync;

  Future<int> pendingCount() => _sync.pendingCount();

  /// Retourne un message de refus si ce tag physique est déjà associé à une autre carte.
  Future<String?> guard(NfcTagRecord tag, String uid, {String? lastUid}) async {
    if (uid.isEmpty || uid == 'INCONNU') return null;
    if (lastUid != null && uid == lastUid) {
      return 'Ce tag vient d’être utilisé pour la carte précédente. Posez un nouveau tag.';
    }
    final local = await _offline.findByUid(userId, uid);
    if (local != null &&
        local.id != tag.id &&
        (local.status == 'written' || local.status == 'verified')) {
      return 'Ce tag (UID $uid) est déjà associé à la carte n° ${local.sequence} (${local.publicId}).';
    }
    try {
      final row = await _remote
          .findByUid(uid)
          .timeout(const Duration(seconds: 3));
      if (row != null) {
        final remote = NfcTagRecord.fromMap(row);
        if (remote.id != tag.id &&
            (remote.status == 'written' || remote.status == 'verified')) {
          return 'Ce tag (UID $uid) est déjà associé à la carte n° ${remote.sequence} (${remote.publicId}).';
        }
      }
    } catch (_) {
      // Hors connexion : le contrôle local et la base (à la synchronisation) restent les garde-fous.
    }
    return null;
  }

  /// Local d'abord (cache + file), puis envoi immédiat si possible. Retourne le nombre restant en file.
  Future<int> record(
    NfcTagRecord tag, {
    required String status,
    String? uid,
    required bool lockTag,
    String? error,
  }) async {
    await _offline.updateResult(
      userId: userId,
      tagId: tag.id,
      status: status,
      uid: uid,
      locked: lockTag,
    );
    await _sync.enqueueWrite(
      tagId: tag.id,
      status: status,
      uid: uid,
      error: error,
      lockTag: lockTag,
    );
    try {
      return (await _sync.syncPending()).remaining;
    } catch (_) {
      return _sync.pendingCount();
    }
  }
}
