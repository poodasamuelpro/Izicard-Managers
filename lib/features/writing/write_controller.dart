import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/app_database.dart';
import '../../data/local/offline_tags_dao.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/models/nfc_tag.dart';
import '../../data/repositories/offline_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/write_recorder.dart';
import '../../services/feedback/feedback_service.dart';
import '../../services/nfc/nfc_service.dart';

enum SeriesPhase { idle, waiting, success, error, paused, finished }

/// Série d'écriture : lit le cache local, écrit, relit, enregistre d'abord en local
/// (file `pending_writes`), puis laisse la synchronisation prévenir la base.
class WriteController extends ChangeNotifier {
  WriteController({
    required TagRepository tags,
    required AppDatabase database,
    required this.userId,
    this.confirmOverwrite,
  }) : _tags = tags,
       _offline = OfflineRepository(
         database: database,
         remote: tags.remote,
         userId: userId,
       ),
       _sync = SyncRepository(
         database: database,
         remote: tags.remote,
         userId: userId,
       ),
       _recorder = WriteRecorder(
         database: database,
         remote: tags.remote,
         userId: userId,
       ),
       _dao = OfflineTagsDao(database);

  final TagRepository _tags;
  final OfflineRepository _offline;
  final SyncRepository _sync;
  final WriteRecorder _recorder;
  final OfflineTagsDao _dao;
  final String userId;
  final Future<bool> Function(String uid, int existingRecordCount)?
  confirmOverwrite;

  List<NfcTagRecord> queue = const [];
  int index = 0;
  SeriesPhase phase = SeriesPhase.idle;
  String message = '';
  String? loadError;
  bool loading = false;
  bool downloaded = false;
  bool lock = false;
  bool autoAdvance = true;
  int verified = 0;
  int errors = 0;
  int skipped = 0;
  int unsynced = 0;
  String? _lastUid;
  bool _running = false;
  bool _pauseRequested = false;

  /// Vrai quand la carte courante est déjà vérifiée : la reprise doit passer à la suivante.
  bool _awaitingAdvance = false;

  NfcTagRecord? get current => index < queue.length ? queue[index] : null;
  bool get isRunning => phase == SeriesPhase.waiting;
  bool get isActive =>
      phase != SeriesPhase.idle && phase != SeriesPhase.finished;

  /// Charge les cartes à écrire depuis le cache local ; télécharge le dossier au besoin.
  Future<void> load(NfcBatch batch) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      if (!await _offline.hasBatch(batch.id)) {
        await _offline.downloadBatch(batch);
        downloaded = true;
      }
      queue = await _offline.writableTags(batch.id);
      index = 0;
      unsynced = await _sync.pendingCount();
    } catch (error) {
      queue = const [];
      loadError =
          await _offline.hasBatch(batch.id)
              ? 'Impossible de lire le cache local : ${_clean(error)}'
              : 'Dossier non téléchargé et réseau indisponible. Téléchargez-le tant que vous avez du réseau : ${_clean(error)}';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Met à jour le cache depuis le serveur (conserve les résultats non synchronisés).
  Future<void> refreshFromServer(NfcBatch batch) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      await _offline.downloadBatch(batch);
      queue = await _offline.writableTags(batch.id);
      index = 0;
    } catch (error) {
      loadError = 'Mise à jour impossible : ${_clean(error)}';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void start({required bool lockAfterWrite, required bool auto}) {
    if (queue.isEmpty || _running) return;
    lock = lockAfterWrite;
    autoAdvance = auto;
    verified = 0;
    errors = 0;
    skipped = 0;
    _lastUid = null;
    _pauseRequested = false;
    unawaited(FeedbackService.keepAwake(true));
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final tag = current;
        if (tag == null) {
          await finish();
          break;
        }
        phase = SeriesPhase.waiting;
        message = 'Approchez le tag n° ${tag.sequence}';
        notifyListeners();

        final result = await NfcService.writeOnce(
          dataType: tag.dataType,
          payload: tag.payload,
          lockAfterWrite: lock,
          guard: (uid) => _guard(tag, uid),
          confirmOverwrite: confirmOverwrite,
        );

        if (result.cancelled) {
          phase = _pauseRequested ? SeriesPhase.paused : SeriesPhase.idle;
          message = _pauseRequested ? 'Série en pause.' : '';
          notifyListeners();
          break;
        }
        await _handle(tag, result);
        if (phase == SeriesPhase.error) break;
        if (!autoAdvance) break; // l'opérateur appuie sur « Suivant »
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (_pauseRequested || phase != SeriesPhase.success) break;
        _advance();
      }
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<String?> _guard(NfcTagRecord tag, String uid) =>
      _recorder.guard(tag, uid, lastUid: _lastUid);

  Future<void> _handle(NfcTagRecord tag, NfcWriteResult result) async {
    if (result.verified) {
      verified++;
      _lastUid = result.uid;
      _awaitingAdvance = true;
      phase = SeriesPhase.success;
      message =
          'Carte n° ${tag.sequence} vérifiée · UID ${result.uid}${result.locked ? ' · verrouillée' : ''}'
          '${result.error != null ? '\n${result.error}' : ''}';
      await _record(
        tag,
        status: 'verified',
        uid: result.uid,
        lockTag: result.locked,
        error: null,
      );
      unawaited(FeedbackService.signal(success: true));
    } else {
      errors++;
      phase = SeriesPhase.error;
      message = result.error ?? 'Écriture non vérifiée.';
      if (result.recordable) {
        await _record(
          tag,
          status: 'error',
          uid: result.uid.isEmpty ? null : result.uid,
          lockTag: false,
          error: message,
        );
      }
      unawaited(FeedbackService.signal(success: false));
    }
    notifyListeners();
  }

  /// Local d'abord (cache + file), puis envoi immédiat si possible.
  Future<void> _record(
    NfcTagRecord tag, {
    required String status,
    String? uid,
    required bool lockTag,
    String? error,
  }) async {
    unsynced = await _recorder.record(
      tag,
      status: status,
      uid: uid,
      lockTag: lockTag,
      error: error,
    );
  }

  void _advance() {
    _awaitingAdvance = false;
    index++;
    if (current == null) {
      unawaited(finish());
    }
  }

  /// « Suivant » quand l'avancement automatique est désactivé.
  void next() {
    if (_running || phase != SeriesPhase.success) return;
    _advance();
    if (phase != SeriesPhase.finished) unawaited(_run());
  }

  void retry() {
    if (_running || phase != SeriesPhase.error) return;
    unawaited(_run());
  }

  void skip() {
    if (_running) return;
    if (phase != SeriesPhase.error &&
        phase != SeriesPhase.paused &&
        phase != SeriesPhase.idle)
      return;
    skipped++;
    _advance();
    if (phase != SeriesPhase.finished) {
      phase = SeriesPhase.paused;
      message = 'Carte passée. Appuyez sur « Reprendre ».';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (phase != SeriesPhase.waiting) {
      if (phase == SeriesPhase.success || phase == SeriesPhase.error) {
        _pauseRequested = true;
        phase = SeriesPhase.paused;
        message = 'Série en pause.';
        notifyListeners();
      }
      return;
    }
    _pauseRequested = true;
    await NfcService.cancel();
  }

  void resume() {
    if (_running || phase != SeriesPhase.paused) return;
    _pauseRequested = false;
    if (_awaitingAdvance) _advance();
    if (phase == SeriesPhase.finished) return;
    unawaited(_run());
  }

  Future<void> finish() async {
    _pauseRequested = true;
    await NfcService.cancel();
    phase = SeriesPhase.finished;
    unawaited(FeedbackService.keepAwake(false));
    notifyListeners();
  }

  String _clean(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    unawaited(NfcService.cancel());
    unawaited(FeedbackService.keepAwake(false));
    super.dispose();
  }
}
