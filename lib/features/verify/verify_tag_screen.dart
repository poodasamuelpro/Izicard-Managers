import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_tag.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/remote/tags_remote.dart';
import '../../services/nfc/ndef_builder.dart';
import '../../data/local/app_database.dart';
import '../../data/local/offline_tags_dao.dart';
import '../../services/feedback/feedback_service.dart';
import '../../services/nfc/nfc_service.dart';
import '../nfc/nfc_help_banner.dart';

class VerifyTagScreen extends StatefulWidget {
  const VerifyTagScreen({super.key});

  @override
  State<VerifyTagScreen> createState() => _VerifyTagScreenState();
}

class _VerifyTagScreenState extends State<VerifyTagScreen> {
  late final TagRepository _tags;
  late final AppDatabase _database;
  late final OfflineTagsDao _offline;
  bool _reading = false;
  String? _error;
  String? _uid;
  String? _result;
  NfcTagRecord? _expected;

  @override
  void initState() {
    super.initState();
    _tags = TagRepository(TagsRemote(Supabase.instance.client));
    _database = AppDatabase();
    _offline = OfflineTagsDao(_database);
  }

  @override
  void dispose() {
    NfcService.cancel();
    _database.close();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _reading = true;
      _error = null;
      _result = null;
      _uid = null;
      _expected = null;
    });
    try {
      final read = await NfcService.readOnce();
      if (read.cancelled) return;
      NfcTagRecord? tag;
      try {
        tag = await _tags
            .findByUid(read.uid)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        // Hors connexion : recherche dans les dossiers téléchargés sur cet appareil.
        tag = await _offline.findByUid(
          Supabase.instance.client.auth.currentUser?.id ?? '',
          read.uid,
        );
      }
      if (!mounted) return;
      final found = tag;
      setState(() {
        _uid = read.uid;
        _expected = found;
        if (found == null) {
          _result = 'Tag inconnu ou non autorisé.';
        } else if (read.message == null) {
          _result = 'Le tag ne contient aucun enregistrement NDEF.';
        } else {
          final expected = NdefPayloadBuilder.build(
            dataType: found.dataType,
            payload: found.payload,
          );
          _result =
              NfcService.sameMessage(read.message!, expected)
                  ? 'Contenu conforme.'
                  : 'Contenu différent du payload attendu.';
        }
      });
    } catch (exception) {
      if (mounted)
        setState(
          () => _error = exception.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) {
        setState(() => _reading = false);
        FeedbackService.signal(success: _result == 'Contenu conforme.');
      }
    }
  }

  Future<void> _cancelReading() => NfcService.cancel();

  @override
  Widget build(BuildContext context) {
    final isOk = _result == 'Contenu conforme.';
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier un tag')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const NfcHelpBanner(),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(
                    Icons.fact_check_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'La vérification lit le tag, retrouve sa carte par UID et compare le contenu réel au payload backend.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _reading ? null : _verify,
                    icon: const Icon(Icons.nfc_rounded),
                    label: const Text('Lire et vérifier'),
                  ),
                  if (_reading) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _cancelReading,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Annuler la lecture'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ResultCard(
              color: IzicardColors.statusError,
              icon: Icons.error_outline,
              title: 'Erreur de lecture',
              message: _error!,
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(
              color:
                  isOk
                      ? IzicardColors.statusVerified
                      : IzicardColors.statusPending,
              icon: isOk ? Icons.verified_rounded : Icons.warning_amber_rounded,
              title: isOk ? 'Conforme ✔' : 'À contrôler ✖',
              message: _result!,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoLine(label: 'UID physique', value: _uid ?? 'Inconnu'),
                    if (_expected != null) ...[
                      _InfoLine(label: 'Carte', value: _expected!.publicId),
                      _InfoLine(label: 'Dossier', value: _expected!.batchId),
                      _InfoLine(
                        label: 'Statut backend',
                        value: _expected!.status,
                      ),
                      _InfoLine(
                        label: 'Payload attendu',
                        value: _expected!.payload,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(message),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    ),
  );
}
