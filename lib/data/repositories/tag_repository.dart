import '../models/nfc_tag.dart';
import '../remote/tags_remote.dart';

class TagRepository {
  TagRepository(this._remote);
  final TagsRemote _remote;

  Future<List<NfcTagRecord>> listWritableTags(String batchId) async =>
      (await _remote.listWritableTags(batchId)).map(NfcTagRecord.fromMap).toList();

  Future<void> markWritten({
    required NfcTagRecord tag,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) => _remote.markWritten(tagId: tag.id, status: status, uid: uid, error: error, lockTag: lockTag);
}
