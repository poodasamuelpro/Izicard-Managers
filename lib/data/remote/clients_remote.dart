import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

class ClientsRemote {
  ClientsRemote(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listClients() async {
    final rows = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_clients')
        .select(
          'id, name, contact_name, email, phone, active, access_expires_at, can_create_batches',
        )
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Nom du client interne qui porte les cartes de l'administrateur (aucun client externe).
  static const internalClientName = 'IziCard Manager — usage interne';
  static const _legacyInternalName = 'IziCardOuaga — usage interne';

  /// Retourne l'identifiant du client interne, en le créant au besoin (administrateur uniquement, via la RLS).
  Future<String> ensureInternalClient() async {
    final table = _client.schema(AppConstants.nfcSchema).from('nfc_clients');
    final found = await table
        .select('id')
        .inFilter('name', [internalClientName, _legacyInternalName])
        .limit(1);
    if (found.isNotEmpty) return found.first['id'].toString();
    final created =
        await table
            .insert({
              'name': internalClientName,
              'contact_name': 'Usage interne',
              'active': true,
            })
            .select('id')
            .single();
    return created['id'].toString();
  }

  Future<void> setClientAccess({
    required String clientId,
    required bool active,
    DateTime? expiresAt,
  }) async {
    await _client
        .schema(AppConstants.nfcSchema)
        .rpc(
          'nfc_set_access',
          params: {
            'p_client': clientId,
            'p_user': null,
            'p_active': active,
            'p_expires': expiresAt?.toUtc().toIso8601String(),
          },
        );
  }

  Future<void> setCanCreateBatches({
    required String clientId,
    required bool allowed,
  }) async {
    await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_clients')
        .update({'can_create_batches': allowed})
        .eq('id', clientId);
  }

  /// Coordonnées métier du client (table nfc_clients, réservée à l'administrateur par la RLS).
  ///
  /// `email` est uniquement l'e-mail de contact enregistré sur le client.
  /// Cette méthode ne touche jamais à l'e-mail du compte Supabase Auth.
  Future<void> updateClient({
    required String clientId,
    required String name,
    String? contactName,
    String? email,
    String? phone,
  }) async {
    String? clean(String? value) {
      final text = value?.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_clients')
        .update({
          'name': name.trim(),
          'contact_name': clean(contactName),
          'email': clean(email),
          'phone': clean(phone),
        })
        .eq('id', clientId);
  }

  Future<Map<String, dynamic>> inviteClient({
    required String fullName,
    required String email,
    required String clientName,
    String? contactName,
    String? phone,
  }) async {
    final response = await _client.functions.invoke(
      'create-client-user',
      body: {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'client_name': clientName.trim(),
        'contact_name': contactName?.trim() ?? '',
        'phone': phone?.trim() ?? '',
      },
    );

    final payload =
        response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
    if (response.status < 200 ||
        response.status >= 300 ||
        payload['error'] != null) {
      throw Exception(payload['error']?.toString() ?? 'Invitation impossible.');
    }
    return payload;
  }
}
