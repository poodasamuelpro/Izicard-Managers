import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

class TagsRemote {
  TagsRemote(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listWritableTags(String batchId) async {
    final rows = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_tags')
        .select('id,batch_id,seq,public_id,data_type,payload,fields,status,uid,locked')
        .eq('batch_id', batchId)
        .inFilter('status', ['pending', 'error'])
        .eq('locked', false)
        .order('seq');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> findByUid(String uid) async {
    final row = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_tags')
        .select('id,batch_id,seq,public_id,data_type,payload,fields,status,uid,locked')
        .eq('uid', uid)
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
