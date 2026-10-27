import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

class BatchesRemote {
  BatchesRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listBatchStats() async {
    final rows = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_batch_stats')
        .select(
          'batch_id, client_id, name, status, quantity, total, pending, written, verified, error, void',
        )
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> getBatchImportContext(String batchId) async {
    final row =
        await _client
            .schema(AppConstants.nfcSchema)
            .from('nfc_batches')
            .select('id, name, format_id, data_type, settings, status')
            .eq('id', batchId)
            .single();
    return Map<String, dynamic>.from(row);
  }

  Future<dynamic> createBatch({
    required String clientId,
    required String formatId,
    required String name,
    required int quantity,
    required String dataType,
    required String? prefix,
    required String? template,
    required bool lockAfterWrite,
    Map<String, dynamic>? settings,
  }) {
    final params = <String, dynamic>{
      'p_client': clientId,
      'p_format': formatId,
      'p_name': name.trim(),
      'p_quantity': quantity,
      'p_data_type': dataType,
      'p_prefix': prefix,
      'p_template': template,
      'p_lock': lockAfterWrite,
    };
    if (settings != null && settings.isNotEmpty)
      params['p_settings'] = settings;
    return _client
        .schema(AppConstants.nfcSchema)
        .rpc('nfc_create_batch', params: params);
  }

  Future<void> archiveBatch({
    required String batchId,
    required bool archived,
  }) async {
    await _client
        .schema(AppConstants.nfcSchema)
        .rpc(
          'nfc_archive_batch',
          params: {'p_batch': batchId, 'p_archived': archived},
        );
  }

  Future<List<Map<String, dynamic>>> listAudit({
    String? entity,
    String? entityId,
    int limit = 100,
  }) async {
    final response = await _client
        .schema(AppConstants.nfcSchema)
        .rpc(
          'nfc_list_audit',
          params: {
            'p_entity': entity,
            'p_entity_id': entityId,
            'p_limit': limit,
          },
        );
    if (response is! List) return const [];
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
