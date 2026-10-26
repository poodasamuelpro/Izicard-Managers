import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card_format.dart';
import '../models/nfc_batch.dart';
import '../models/nfc_client.dart';
import '../remote/batches_remote.dart';
import '../remote/clients_remote.dart';
import '../remote/formats_remote.dart';
import '../remote/tags_remote.dart';

class BatchRepository {
  BatchRepository(SupabaseClient client)
      : _batches = BatchesRemote(client),
        _clients = ClientsRemote(client),
        _formats = FormatsRemote(client),
        _tags = TagsRemote(client);

  final BatchesRemote _batches;
  final ClientsRemote _clients;
  final FormatsRemote _formats;
  final TagsRemote _tags;

  Future<List<NfcBatch>> listBatchStats() async =>
      (await _batches.listBatchStats()).map(NfcBatch.fromStats).toList();

  Future<List<NfcClient>> listClients() async =>
      (await _clients.listClients()).map(NfcClient.fromMap).toList();

  Future<List<CardFormat>> listActiveFormats() async =>
      (await _formats.listActiveFormats()).map(CardFormat.fromMap).toList();

  Future<BatchImportContext> getImportContext(String batchId) async {
    final row = await _batches.getBatchImportContext(batchId);
    final format = CardFormat.fromMap(await _formats.getFormat(row['format_id'].toString()));
    final rawSettings = row['settings'];
    return BatchImportContext(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? 'Dossier',
      dataType: row['data_type']?.toString() ?? format.defaultDataType,
      format: format,
      settings: rawSettings is Map ? Map<String, dynamic>.from(rawSettings) : const {},
      status: row['status']?.toString() ?? 'draft',
    );
  }

  Future<String> createBatch({
    required String clientId,
    required String formatId,
    required String name,
    required int quantity,
    required String dataType,
    required bool lockAfterWrite,
    Map<String, dynamic>? settings,
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
      settings: settings,
    );
    if (result == null || result.toString().isEmpty) {
      throw const FormatException('Supabase n’a pas retourné l’identifiant du dossier.');
    }
    return result.toString();
  }

  Future<Map<String, dynamic>> importRows({
    required String batchId,
    required List<Map<String, dynamic>> rows,
    String? filename,
    Map<String, dynamic>? mapping,
  }) => _tags.importRows(
        batchId: batchId,
        rows: rows,
        filename: filename,
        mapping: mapping,
      );

  Future<void> archiveBatch({required String batchId, required bool archived}) =>
      _batches.archiveBatch(batchId: batchId, archived: archived);

  Future<List<Map<String, dynamic>>> listAudit({String? entity, String? entityId, int limit = 100}) =>
      _batches.listAudit(entity: entity, entityId: entityId, limit: limit);
}
