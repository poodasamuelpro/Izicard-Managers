import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

class BatchesRemote {
  BatchesRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listBatchStats() async {
    final rows = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_batch_stats')
        .select('batch_id, client_id, name, status, quantity, total, pending, written, verified, error, void')
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
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
  }) {
    return _client.schema(AppConstants.nfcSchema).rpc(
      'nfc_create_batch',
      params: {
        'p_client': clientId,
        'p_format': formatId,
        'p_name': name.trim(),
        'p_quantity': quantity,
        'p_data_type': dataType,
        'p_prefix': prefix,
        'p_template': template,
        'p_lock': lockAfterWrite,
      },
    );
  }
}
