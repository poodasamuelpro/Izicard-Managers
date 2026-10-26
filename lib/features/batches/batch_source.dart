import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/app_database.dart';
import '../../data/local/offline_tags_dao.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/repositories/batch_repository.dart';

class BatchList {
  const BatchList(this.batches, {required this.offline});
  final List<NfcBatch> batches;

  /// Vrai quand la liste vient du cache de l'appareil (réseau indisponible).
  final bool offline;
}

/// Liste des dossiers : en ligne si possible, sinon dossiers déjà téléchargés sur cet appareil.
/// Si le réseau échoue et qu'aucun dossier n'est téléchargé, l'erreur d'origine est relancée.
Future<BatchList> loadBatches(BatchRepository repository) async {
  try {
    return BatchList(await repository.listBatchStats(), offline: false);
  } catch (_) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) rethrow;
    final database = AppDatabase();
    try {
      final local = await OfflineTagsDao(database).downloadedBatches(userId);
      if (local.isEmpty) rethrow;
      return BatchList(local.map((info) => info.batch).toList(), offline: true);
    } finally {
      await database.close();
    }
  }
}
