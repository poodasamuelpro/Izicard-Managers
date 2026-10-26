import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/nfc_profile.dart';
import '../../data/local/app_database.dart';
import '../../data/local/offline_tags_dao.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../../data/remote/tags_remote.dart';
import '../../features/admin/batches/batch_create_screen.dart';
import '../../features/admin/clients/clients_screen.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart';
import '../../features/batches/batches_screen.dart';
import '../../features/export/export_screen.dart';
import '../../features/import/import_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sync/sync_status_screen.dart';
import '../../features/verify/verify_tag_screen.dart';
import '../../features/writing/write_screen.dart';

/// Destinations accessibles depuis l'accueil, protégées à nouveau par les RPC/RLS.
enum NfcDestination {
  dashboard,
  clients,
  batches,
  createBatch,
  imports,
  export,
  write,
  verify,
  sync,
  settings,
}

extension NfcDestinationDetails on NfcDestination {
  String get title => switch (this) {
        NfcDestination.dashboard => 'Tableau de bord',
        NfcDestination.clients => 'Clients et accès',
        NfcDestination.batches => 'Dossiers NFC',
        NfcDestination.createBatch => 'Créer un dossier',
        NfcDestination.imports => 'Importer des données',
        NfcDestination.export => 'Exporter les données',
        NfcDestination.write => 'Écriture NFC',
        NfcDestination.verify => 'Vérifier un tag',
        NfcDestination.sync => 'Synchronisation',
        NfcDestination.settings => 'Réglages',
      };

  String get description => switch (this) {
        NfcDestination.dashboard => 'Vue d’ensemble : clients, dossiers et avancement des cartes.',
        NfcDestination.clients => 'Gérez les clients, leurs profils et leurs accès.',
        NfcDestination.batches => 'Consultez les dossiers qui vous sont attribués.',
        NfcDestination.createBatch => 'Préparez un dossier pour votre client.',
        NfcDestination.imports => 'Importez un fichier ou saisissez une carte.',
        NfcDestination.export => 'Téléchargez les données et rapports des dossiers.',
        NfcDestination.write => 'Écrivez et vérifiez les tags NFC associés à un dossier.',
        NfcDestination.verify => 'Relisez un tag et contrôlez les données encodées.',
        NfcDestination.sync => 'Consultez les opérations en attente de synchronisation.',
        NfcDestination.settings => 'Consultez les paramètres de votre espace IziCard.',
      };

  bool allowedFor(NfcProfile profile) => switch (this) {
        NfcDestination.dashboard ||
        NfcDestination.clients => profile.role == NfcRole.admin,
        NfcDestination.createBatch => profile.role == NfcRole.admin ||
            (profile.role == NfcRole.client && profile.canCreateBatches && profile.clientId != null),
        NfcDestination.imports ||
        NfcDestination.export ||
        NfcDestination.batches ||
        NfcDestination.write ||
        NfcDestination.verify ||
        NfcDestination.sync ||
        NfcDestination.settings => true,
      };
}

class NfcRouteGuard {
  const NfcRouteGuard._();

  static bool canOpen(NfcProfile profile, NfcDestination destination) =>
      profile.hasValidAccess && destination.allowedFor(profile);

  static Future<void> open(
    BuildContext context, {
    required NfcProfile profile,
    required NfcDestination destination,
    required AuthRepository repository,
  }) async {
    if (!canOpen(profile, destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n’avez pas accès à cette fonctionnalité.')),
      );
      return;
    }

    final client = Supabase.instance.client;
    final batches = BatchRepository(client);
    final database = AppDatabase();
    final userId = client.auth.currentUser?.id ?? '';
    try {
      await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => switch (destination) {
          NfcDestination.dashboard => AdminDashboardScreen(profile: profile, repository: batches, clients: ClientRepository(client)),
          NfcDestination.batches => BatchesScreen(profile: profile, repository: batches),
          NfcDestination.createBatch => BatchCreateScreen(profile: profile, repository: batches),
          NfcDestination.imports => ImportScreen(profile: profile, repository: batches),
          NfcDestination.clients => ClientsScreen(repository: ClientRepository(client)),
          NfcDestination.write => WriteScreen(profile: profile),
          NfcDestination.verify => const VerifyTagScreen(),
          NfcDestination.export => ExportScreen(repository: batches),
          NfcDestination.settings => SettingsScreen(profile: profile, repository: repository, email: client.auth.currentUser?.email ?? ''),
          NfcDestination.sync => SyncStatusScreen(
              repository: SyncRepository(database: database, remote: TagsRemote(client), userId: userId),
              offline: OfflineTagsDao(database),
              userId: userId,
            ),
        },
      ),
      );
    } finally {
      await database.close();
    }
  }
}
