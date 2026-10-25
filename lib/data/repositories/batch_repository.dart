import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card_format.dart';
import '../models/nfc_batch.dart';
import '../models/nfc_client.dart';
import '../remote/batches_remote.dart';
import '../remote/clients_remote.dart';
import '../remote/formats_remote.dart';

class BatchRepository {
  BatchRepository(SupabaseClient client)
      : _batches = BatchesRemote(client),
        _clients = ClientsRemote(client),
        _formats = FormatsRemote(client);

  final BatchesRemote _batches;
  final ClientsRemote _clients;
  final FormatsRemote _formats;

  Future<List<NfcBatch>> listBatchStats() async =>
      (await _batches.listBatchStats()).map(NfcBatch.fromStats).toList();

  Future<List<NfcClient>> listClients() async =>
      (await _clients.listClients()).map(NfcClient.fromMap).toList();

  Future<List<CardFormat>> listActiveFormats() async =>
      (await _formats.listActiveFormats()).map(CardFormat.fromMap).toList();

  Future<String> createBatch({
    required String clientId,
    required String formatId,
    required String name,
    required int quantity,
    required String dataType,
    required bool lockAfterWrite,
  }) async {
    final result = await _batches.createBatch(
      clientId: clientId,
      formatId: formatId,
      name: name,
      quantity: quantity,
      dataType: dataType,
      prefix: null,
      template: null,
      lockAfterWrite: lockAfterWrite,
    );
    if (result == null || result.toString().isEmpty) {
      throw const FormatException('Supabase n’a pas retourné l’identifiant du dossier.');
    }
    return result.toString();
  }
}
