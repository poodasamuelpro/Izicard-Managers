import '../models/nfc_tag.dart';
import '../remote/tags_remote.dart';

class TagRepository {
  TagRepository(this._remote);
  final TagsRemote _remote;

  TagsRemote get remote => _remote;

  Future<List<NfcTagRecord>> listWritableTags(String batchId) async =>
      (await _remote.listWritableTags(batchId)).map(NfcTagRecord.fromMap).toList();

  Future<List<NfcTagRecord>> page({
    required String batchId,
    String? status,
    String? search,
    required int offset,
    int limit = 50,
  }) async =>
      (await _remote.listTagsPage(batchId: batchId, status: status, search: search, offset: offset, limit: limit))
          .map(NfcTagRecord.fromMap)
          .toList();

  Future<List<NfcTagRecord>> all(String batchId) async =>
      (await _remote.listAllTags(batchId)).map(NfcTagRecord.fromMap).toList();

  Future<NfcTagRecord?> findByUid(String uid) async {
    final row = await _remote.findByUid(uid);
    return row == null ? null : NfcTagRecord.fromMap(row);
  }

  Future<void> markWritten({
    required NfcTagRecord tag,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) => _remote.markWritten(tagId: tag.id, status: status, uid: uid, error: error, lockTag: lockTag);
}
