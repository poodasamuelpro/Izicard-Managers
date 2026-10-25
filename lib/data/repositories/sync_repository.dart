import '../local/app_database.dart';
import '../local/pending_writes_dao.dart';
import '../remote/tags_remote.dart';

class SyncResult {
  const SyncResult({required this.sent, required this.remaining});
  final int sent;
  final int remaining;
}

class SyncRepository {
  SyncRepository({required AppDatabase database, required TagsRemote remote})
      : _queue = PendingWritesDao(database),
        _remote = remote;

  final PendingWritesDao _queue;
  final TagsRemote _remote;

  PendingWritesDao get queue => _queue;

  Future<void> enqueueWrite({
    required String tagId,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) => _queue.enqueue(
        tagId: tagId,
        status: status,
        uid: uid,
        error: error,
        lockTag: lockTag,
      ).then((_) {});

  Future<SyncResult> syncPending() async {
    var sent = 0;
    final items = await _queue.pending(limit: 200);
    for (final item in items) {
      await _queue.markAttempt(item.id);
      try {
        await _remote.markWritten(
          tagId: item.tagId,
          status: item.status,
          uid: item.uid,
          error: item.error,
          lockTag: item.lockTag,
        );
        await _queue.remove(item.id);
        sent++;
      } catch (_) {
        // Conserver l’élément : il sera repris au prochain retour réseau.
        break;
      }
    }
    return SyncResult(sent: sent, remaining: await _queue.count());
  }
}
