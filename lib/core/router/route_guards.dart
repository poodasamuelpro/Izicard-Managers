import 'package:flutter/material.dart';

import '../../data/models/nfc_profile.dart';
import '../../features/home/module_screen.dart';

enum NfcDestination {
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
        NfcDestination.clients =>
          'Gérez les clients, leurs profils et leurs accès à la plateforme.',
        NfcDestination.batches =>
          'Consultez les dossiers et suivez leur progression.',
        NfcDestination.createBatch =>
          'Préparez un nouveau dossier d’encodage NFC.',
        NfcDestination.imports =>
          'Importez et contrôlez les données des cartes.',
        NfcDestination.export =>
          'Téléchargez les données et rapports des dossiers.',
        NfcDestination.write =>
          'Écrivez et vérifiez les tags NFC associés à un dossier.',
        NfcDestination.verify =>
          'Relisez un tag et contrôlez les données encodées.',
        NfcDestination.sync =>
          'Consultez les opérations en attente de synchronisation.',
        NfcDestination.settings =>
          'Consultez les paramètres de votre espace IziCard.',
      };

  bool allowedFor(NfcProfile profile) => switch (this) {
        NfcDestination.clients ||
        NfcDestination.imports ||
        NfcDestination.export => profile.role == NfcRole.admin,
        NfcDestination.createBatch =>
          profile.role == NfcRole.admin || profile.canCreateBatches,
        NfcDestination.batches ||
        NfcDestination.write ||
        NfcDestination.verify ||
        NfcDestination.sync ||
        NfcDestination.settings => true,
      };
}

class NfcRouteGuard {
  const NfcRouteGuard._();

  static bool canOpen(NfcProfile profile, NfcDestination destination) {
    return profile.hasValidAccess && destination.allowedFor(profile);
  }

  static Future<void> open(
    BuildContext context, {
    required NfcProfile profile,
    required NfcDestination destination,
  }) async {
    if (!canOpen(profile, destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n’avez pas accès à cette fonctionnalité.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NfcModuleScreen(
          destination: destination,
          profile: profile,
        ),
      ),
    );
  }
}
