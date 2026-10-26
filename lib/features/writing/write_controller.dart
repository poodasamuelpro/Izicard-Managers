import '../../data/local/app_database.dart';
import '../../data/models/nfc_tag.dart';
import '../../data/repositories/sync_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../services/nfc/nfc_service.dart';

class WriteItemResult {
  const WriteItemResult({required this.tag, this.status = 'pending', this.message, this.uid});

  final NfcTagRecord tag;
  final String status;
  final String? message;
  final String? uid;

  WriteItemResult copyWith({String? status, String? message, String? uid, bool clearMessage = false, bool clearUid = false}) => WriteItemResult(
        tag: tag,
        status: status ?? this.status,
        message: clearMessage ? null : message ?? this.message,
        uid: clearUid ? null : uid ?? this.uid,
      );
}

class WriteController {
  WriteController({required TagRepository tags, required AppDatabase database, required String userId})
      : _tags = tags,
        _sync = SyncRepository(database: database, remote: tags.remote, userId: userId);

  final TagRepository _tags;
  final SyncRepository _sync;
  List<WriteItemResult> items = const [];
  int currentIndex = 0;
  bool loading = false;
  bool processing = false;
  String? error;

  NfcTagRecord? get currentTag => currentIndex < items.length ? items[currentIndex].tag : null;
  WriteItemResult? get currentResult => currentIndex < items.length ? items[currentIndex] : null;
  bool get isComplete => items.isNotEmpty && items.every((item) => item.status == 'verified' || item.status == 'skipped');

  Future<void> load(String batchId) async {
    loading = true;
    error = null;
    try {
      final tags = await _tags.listWritableTags(batchId);
      items = tags.map((tag) => WriteItemResult(tag: tag)).toList();
      currentIndex = 0;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
      items = const [];
    } finally {
      loading = false;
    }
  }

  Future<void> writeCurrent({required bool lockAfterWrite}) async {
    final result = currentResult;
    if (result == null || processing) return;
    processing = true;
    error = null;
    _setCurrent(result.copyWith(status: 'writing', message: 'Approchez le tag du téléphone…'));
    try {
      final nfc = await NfcService.writeOnce(
        dataType: result.tag.dataType,
        payload: result.tag.payload,
        lockAfterWrite: lockAfterWrite || result.tag.locked,
      );
      final status = nfc.verified ? 'verified' : 'error';
      final message = nfc.verified ? 'Écriture et relecture confirmées.' : nfc.error ?? 'Écriture non vérifiée.';
      _setCurrent(result.copyWith(status: status, message: message, uid: nfc.uid));
      await _recordResult(
        tag: result.tag,
        status: status,
        uid: nfc.uid,
        error: nfc.verified ? null : message,
        lockTag: lockAfterWrite || result.tag.locked,
      );
      if (nfc.verified) _advanceToNextPending();
    } catch (exception) {
      final message = exception.toString().replaceFirst('Exception: ', '');
      _setCurrent(result.copyWith(status: 'error', message: message));
      await _recordResult(tag: result.tag, status: 'error', error: message, lockTag: false);
    } finally {
      processing = false;
    }
  }

  void skipCurrent() {
    final result = currentResult;
    if (result == null || processing) return;
    _setCurrent(result.copyWith(status: 'skipped', message: 'Carte passée par l’opérateur.'));
    _advanceToNextPending();
  }

  void retryCurrent() {
    final result = currentResult;
    if (result == null || processing) return;
    _setCurrent(result.copyWith(status: 'pending', clearMessage: true, clearUid: true));
  }

  void _setCurrent(WriteItemResult value) {
    final copy = [...items];
    copy[currentIndex] = value;
    items = copy;
  }

  void _advanceToNextPending() {
    for (var index = currentIndex + 1; index < items.length; index++) {
      if (items[index].status == 'pending' || items[index].status == 'error') {
        currentIndex = index;
        return;
      }
    }
  }

  Future<void> _recordResult({
    required NfcTagRecord tag,
    required String status,
    String? uid,
    String? error,
    required bool lockTag,
  }) async {
    try {
      await _tags.markWritten(tag: tag, status: status, uid: uid, error: error, lockTag: lockTag);
    } catch (_) {
      await _sync.enqueueWrite(
        tagId: tag.id,
        status: status,
        uid: uid,
        error: error,
        lockTag: lockTag,
      );
    }
  }
}
