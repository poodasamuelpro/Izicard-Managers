import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

class FormatsRemote {
  FormatsRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listActiveFormats() async {
    final rows = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_card_formats')
        .select('id, code, label, product, chip, capacity_bytes, default_data_type, payload_template, id_prefix, id_length, lock_default, field_schema, rules, active')
        .eq('active', true)
        .order('label');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> getFormat(String formatId) async {
    final row = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_card_formats')
        .select('id, code, label, product, chip, capacity_bytes, default_data_type, payload_template, id_prefix, id_length, lock_default, field_schema, rules, active')
        .eq('id', formatId)
        .single();
    return Map<String, dynamic>.from(row);
  }
}
