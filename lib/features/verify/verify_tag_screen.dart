import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/izicard_colors.dart';
import '../../core/widgets/izi_ui.dart';
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
  NfcTagRecord? _expected;

  /// Appartenance : le tag est-il enregistré dans IziCard Manager ?
  bool? _owned;

  /// Contenu : null = pas de verdict possible (tag inconnu).
  bool? _contentOk;
  String? _contentVerdict;
  String? _contentRead;
  String? _chip;
  Map<String, String> _details = const {};

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

  /// Décrit un enregistrement NDEF (type, taille, contenu lisible).
  static String _describeRecord(NdefRecord record) {
    final type = String.fromCharCodes(record.type);
    final payload = record.payload;
    final size = '${payload.length} octets';
    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        type == 'U' &&
        payload.isNotEmpty) {
      return 'Lien : ${NdefPayloadBuilder.decodeUri(payload)} ($size)';
    }
    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        type == 'T' &&
        payload.isNotEmpty) {
      final lang = payload.first & 0x3f;
      final start = 1 + lang;
      final text =
          start <= payload.length
              ? utf8.decode(payload.sublist(start), allowMalformed: true)
              : '';
      return 'Texte : $text ($size)';
    }
    if (type == 'text/vcard') {
      return 'Fiche contact (vCard), $size :\n${utf8.decode(payload, allowMalformed: true)}';
    }
    final text = utf8.decode(payload, allowMalformed: true);
    return 'Type ${type.isEmpty ? 'inconnu' : type} ($size) : $text';
  }

  /// Tous les enregistrements NDEF lus, un par ligne.
  static String _describe(NdefMessage? message) {
    final records = NfcService.contentRecords(message);
    if (records.isEmpty) {
      return 'Aucun contenu (tag vide).';
    }
    final lines = <String>[];
    for (var i = 0; i < records.length; i++) {
      lines.add('#${i + 1} ${_describeRecord(records[i])}');
    }
    return lines.join('\n');
  }

  /// Modèle de puce probable d'après la capacité NDEF annoncée.
  static String? _chipFromSize(int? size) {
    if (size == null) return null;
    final model =
        size <= 150
            ? 'NTAG213'
            : size <= 520
            ? 'NTAG215'
            : size <= 900
            ? 'NTAG216'
            : 'autre puce';
    return '$model probable ($size octets NDEF utilisables)';
  }

  Future<void> _verify() async {
    setState(() {
      _reading = true;
      _error = null;
      _uid = null;
      _expected = null;
      _owned = null;
      _contentOk = null;
      _contentVerdict = null;
      _contentRead = null;
      _chip = null;
      _details = const {};
    });
    var success = false;
    try {
      final read = await NfcService.readOnce();
      if (read.cancelled) return;
      NfcTagRecord? tag;
      try {
        tag = await _tags
            .findByUid(read.uid)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        tag = await _offline.findByUid(
          Supabase.instance.client.auth.currentUser?.id ?? '',
          read.uid,
        );
      }
      if (!mounted) return;
      final found = tag;
      final message = read.message;
      bool? contentOk;
      String verdict;
      if (found == null) {
        verdict =
            NfcService.isBlank(message)
                ? 'Aucun contenu lu : tag vide ou non NDEF.'
                : 'Contenu lu ci-dessous. Aucune comparaison possible : ce tag n’est pas enregistré.';
      } else if (NfcService.isBlank(message)) {
        contentOk = false;
        verdict = 'Le tag ne contient aucun enregistrement NDEF.';
      } else {
        final expected = NdefPayloadBuilder.build(
          dataType: found.dataType,
          payload: found.payload,
        );
        contentOk = NfcService.sameMessage(message!, expected);
        verdict =
            contentOk
                ? 'Contenu conforme à ce qui devait être écrit.'
                : 'Contenu différent de ce qui devait être écrit.';
      }
      success = found != null && contentOk == true;
      setState(() {
        _uid = read.uid;
        _expected = found;
        _owned = found != null;
        _contentOk = contentOk;
        _contentVerdict = verdict;
        _contentRead = _describe(message);
        _chip = _chipFromSize(read.maxSize);
        _details = read.details;
      });
    } catch (exception) {
      if (mounted)
        setState(
          () => _error = exception.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) {
        setState(() => _reading = false);
        FeedbackService.signal(success: success);
      }
    }
  }

  Future<void> _cancelReading() => NfcService.cancel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier un tag')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const NfcHelpBanner(),
          const IziHero(
            icon: Icons.fact_check_rounded,
            title: 'Contrôle d’un tag',
            subtitle:
                'Deux vérifications : le tag appartient-il à IziCard Manager (UID enregistré), et son contenu est-il celui attendu.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _reading ? null : _verify,
            icon: const Icon(Icons.nfc_rounded),
            label: Text(_reading ? 'Approchez le tag…' : 'Lire et vérifier'),
          ),
          if (_reading) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _cancelReading,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Annuler la lecture'),
            ),
          ],
          if (_error != null) ...[
            const IziSectionTitle('Résultat'),
            _ResultCard(
              tone: IziTone.error,
              title: 'Erreur de lecture',
              message: _error!,
            ),
          ],
          if (_owned != null) ...[
            const IziSectionTitle('Résultat'),
            _ResultCard(
              tone: _owned! ? IziTone.success : IziTone.warning,
              title:
                  _owned!
                      ? '1. Appartenance : tag IziCard Manager'
                      : '1. Appartenance : tag non enregistré',
              message:
                  _owned!
                      ? 'Cet UID est enregistré dans un de vos dossiers.'
                      : 'Cet UID n’est enregistré dans aucun dossier accessible avec votre compte (tag étranger, tag d’un autre client ou carte pas encore créée).',
            ),
            const SizedBox(height: 10),
            _ResultCard(
              tone: _contentOk == true ? IziTone.success : IziTone.warning,
              title:
                  _contentOk == true
                      ? '2. Contenu : conforme'
                      : _contentOk == false
                      ? '2. Contenu : à contrôler'
                      : '2. Contenu : non comparé',
              message: _contentVerdict ?? '',
            ),
            const IziSectionTitle('Détails du tag'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoLine(label: 'UID physique', value: _uid ?? 'Inconnu'),
                    _InfoLine(
                      label: 'Contenu NDEF lu sur le tag',
                      value: _contentRead ?? '—',
                    ),
                    if (_chip != null) _InfoLine(label: 'Puce', value: _chip!),
                    ..._details.entries.map(
                      (entry) =>
                          _InfoLine(label: entry.key, value: entry.value),
                    ),
                  ],
                ),
              ),
            ),
            if (_expected != null) ...[
              const IziSectionTitle('Carte enregistrée'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoLine(label: 'Carte', value: _expected!.publicId),
                      _InfoLine(label: 'Dossier', value: _expected!.batchId),
                      _InfoLine(
                        label: 'Statut de la carte',
                        value: _expected!.status,
                      ),
                      _InfoLine(
                        label: 'Contenu attendu',
                        value: _expected!.payload,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.tone,
    required this.title,
    required this.message,
  });
  final IziTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) =>
      IziNotice(message, tone: tone, title: title);
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
