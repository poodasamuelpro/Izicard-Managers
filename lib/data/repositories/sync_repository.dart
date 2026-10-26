import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../local/pending_writes_dao.dart';
import '../remote/tags_remote.dart';

class SyncResult {
  const SyncResult({required this.sent, required this.remaining, this.rejected = 0, this.blocked = false});
  final int sent;
  final int remaining;

  /// Éléments refusés définitivement par la base pendant cette passe.
  final int rejected;

  /// Vrai si la session courante n'est pas celle du propriétaire de la file.
  final bool blocked;
}

class SyncRepository {
  SyncRepository({
    required AppDatabase database,
    required TagsRemote remote,
    required this.userId,
    String? Function()? sessionUserId,
  })  : _queue = PendingWritesDao(database),
        _remote = remote,
        _sessionUserId = sessionUserId ?? (() => Supabase.instance.client.auth.currentUser?.id);

  final PendingWritesDao _queue;
  final TagsRemote _remote;
  final String userId;
  final String? Function() _sessionUserId;

  PendingWritesDao get queue => _queue;

  Future<void> enqueueWrite({
    required String tagId,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) =>
      _queue
          .enqueue(userId: userId, tagId: tagId, status: status, uid: uid, error: error, lockTag: lockTag)
          .then((_) {});

  Future<List<PendingWrite>> items({bool includePermanent = true}) =>
      _queue.pending(userId, includePermanent: includePermanent);

  Future<int> pendingCount() => _queue.count(userId);

  Future<void> retry(int id) => _queue.retry(id);
  Future<void> discard(int id) => _queue.remove(id);

  /// Envoi séquentiel. Réseau coupé : on garde tout et on s'arrête.
  /// Refus définitif de la base : l'élément est conservé, marqué, et la file continue.
  /// Session expirée ou autre compte : on s'arrête sans rien supprimer.
  Future<SyncResult> syncPending() async {
    if (_sessionUserId() != userId) {
      return SyncResult(sent: 0, remaining: await _queue.count(userId), blocked: true);
    }
    var sent = 0;
    var rejected = 0;
    final items = await _queue.pending(userId, limit: 500);
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
      } on PostgrestException catch (error) {
        if (_isTemporary(error)) break;
        await _queue.markPermanent(item.id, error.message);
        rejected++;
      } on AuthException {
        break;
      } catch (_) {
        break;
      }
    }
    return SyncResult(sent: sent, remaining: await _queue.count(userId), rejected: rejected);
  }

  /// Erreur de réseau/serveur ou session expirée : à réessayer, jamais définitive.
  static bool _isTemporary(PostgrestException error) {
    final code = error.code ?? '';
    if (code.isEmpty) return true;
    if (code == 'PGRST301' || code == '401' || code == '408' || code == '429') return true;
    if (code.startsWith('5')) return true;
    return error.message.toLowerCase().contains('jwt');
  }
}
