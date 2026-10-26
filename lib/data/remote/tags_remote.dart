import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

const _tagColumns = 'id,batch_id,seq,public_id,data_type,payload,fields,status,uid,locked,attempts,last_error,written_at';

class TagsRemote {
  TagsRemote(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listWritableTags(String batchId) async {
    final rows = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_tags')
        .select(_tagColumns)
        .eq('batch_id', batchId)
        .inFilter('status', ['pending', 'error'])
        .eq('locked', false)
        .order('seq');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Page de cartes d'un dossier, avec filtre de statut et recherche
  /// (identifiant, UID, référence, code, nom). La RLS limite aux données autorisées.
  Future<List<Map<String, dynamic>>> listTagsPage({
    required String batchId,
    String? status,
    String? search,
    required int offset,
    int limit = 50,
  }) async {
    var query = _client.schema(AppConstants.nfcSchema).from('nfc_tags').select(_tagColumns).eq('batch_id', batchId);
    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    final term = (search ?? '').replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
    if (term.isNotEmpty) {
      final like = '%$term%';
      query = query.or('public_id.ilike.$like,uid.ilike.$like,fields->>ref.ilike.$like,fields->>code.ilike.$like,fields->>full_name.ilike.$like');
    }
    final rows = await query.order('seq').range(offset, offset + limit - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Toutes les cartes d'un dossier (export, téléchargement hors-ligne), par blocs de 1000.
  Future<List<Map<String, dynamic>>> listAllTags(String batchId) async {
    final all = <Map<String, dynamic>>[];
    for (var from = 0;; from += 1000) {
      final rows = await _client
          .schema(AppConstants.nfcSchema)
          .from('nfc_tags')
          .select(_tagColumns)
          .eq('batch_id', batchId)
          .order('seq')
          .range(from, from + 999);
      all.addAll(rows.map((row) => Map<String, dynamic>.from(row)));
      if (rows.length < 1000) break;
    }
    return all;
  }

  Future<Map<String, dynamic>?> findByUid(String uid) async {
    final row = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_tags')
        .select(_tagColumns)
        .eq('uid', uid)
        .neq('status', 'void')
        .limit(1)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> markWritten({
    required String tagId,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) async {
    await _client.schema(AppConstants.nfcSchema).rpc(
      'nfc_mark_written',
      params: {
        'p_tag': tagId,
        'p_status': status,
        'p_uid': uid,
        'p_error': error,
        'p_lock': lockTag,
      },
    );
  }

  Future<Map<String, dynamic>> importRows({
    required String batchId,
    required List<Map<String, dynamic>> rows,
    String? filename,
    Map<String, dynamic>? mapping,
  }) async {
    final response = await _client.schema(AppConstants.nfcSchema).rpc(
      'nfc_import_rows',
      params: {
        'p_batch': batchId,
        'p_rows': rows,
        'p_filename': filename,
        'p_mapping': mapping,
      },
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const FormatException('Réponse d’import nfc_import_rows invalide.');
  }
}
