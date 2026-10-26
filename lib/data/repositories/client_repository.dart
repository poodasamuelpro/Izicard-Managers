import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nfc_client.dart';
import '../remote/clients_remote.dart';

class ClientRepository {
  ClientRepository(SupabaseClient client) : _remote = ClientsRemote(client);

  final ClientsRemote _remote;

  Future<List<NfcClient>> listClients() async =>
      (await _remote.listClients()).map(NfcClient.fromMap).toList();

  Future<void> setAccess({
    required String clientId,
    required bool active,
    DateTime? expiresAt,
  }) {
    return _remote.setClientAccess(
      clientId: clientId,
      active: active,
      expiresAt: expiresAt,
    );
  }

  Future<void> setCanCreateBatches({
    required String clientId,
    required bool allowed,
  }) => _remote.setCanCreateBatches(clientId: clientId, allowed: allowed);

  Future<void> updateClient({
    required String clientId,
    required String name,
    String? contactName,
    String? email,
    String? phone,
  }) => _remote.updateClient(
        clientId: clientId,
        name: name,
        contactName: contactName,
        email: email,
        phone: phone,
      );

  Future<Map<String, dynamic>> inviteClient({
    required String fullName,
    required String email,
    required String clientName,
    String? contactName,
    String? phone,
  }) {
    return _remote.inviteClient(
      fullName: fullName,
      email: email,
      clientName: clientName,
      contactName: contactName,
      phone: phone,
    );
  }
}
