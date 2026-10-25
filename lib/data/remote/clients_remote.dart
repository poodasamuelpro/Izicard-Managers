import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

class ClientsRemote {
  ClientsRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listClients() async {
    final rows = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_clients')
        .select('id, name, contact_name, email, phone, active, access_expires_at, can_create_batches')
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> setClientAccess({
    required String clientId,
    required bool active,
    DateTime? expiresAt,
  }) async {
    await _client.schema(AppConstants.nfcSchema).rpc(
      'nfc_set_access',
      params: {
        'p_client': clientId,
        'p_user': null,
        'p_active': active,
        'p_expires': expiresAt?.toUtc().toIso8601String(),
      },
    );
  }
}
