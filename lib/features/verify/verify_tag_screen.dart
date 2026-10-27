import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nfc_manager/ndef_record.dart';
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
  NfcTagRecord? _expected;

  /// Appartenance : le tag est-il enregistré dans IziCardOuaga ?
  bool? _owned;

  /// Contenu : null = pas de verdict possible (tag inconnu).
  bool? _contentOk;
  String? _contentVerdict;
  String? _contentRead;
  String? _chip;

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

  /// Texte lisible du premier enregistrement NDEF lu sur le tag.
  static String _describe(NdefMessage? message) {
    if (message == null || message.records.isEmpty) {
      return 'Aucun contenu (tag vide).';
    }
    final record = message.records.first;
    final type = String.fromCharCodes(record.type);
    final payload = record.payload;
    final extra =
        message.records.length > 1
            ? ' (+${message.records.length - 1} autre(s) enregistrement(s))'
            : '';
    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        type == 'U' &&
        payload.isNotEmpty) {
      const prefixes = [
        '',
        'http://www.',
        'https://www.',
        'http://',
        'https://',
        'tel:',
        'mailto:',
      ];
      final code = payload.first;
      final prefix = code < prefixes.length ? prefixes[code] : '';
      return 'Lien : $prefix${utf8.decode(payload.sublist(1), allowMalformed: true)}$extra';
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
      return 'Texte : $text$extra';
    }
    if (type == 'text/vcard') return 'Fiche contact (vCard)$extra';
    return 'Contenu de type ${type.isEmpty ? 'inconnu' : type}$extra';
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
    return '$model probable ($size octets utilisables)';
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
            message == null || message.records.isEmpty
                ? 'Aucun contenu lu : tag vide ou non NDEF.'
                : 'Contenu lu ci-dessous. Aucune comparaison possible : ce tag n’est pas enregistré.';
      } else if (message == null || message.records.isEmpty) {
        contentOk = false;
        verdict = 'Le tag ne contient aucun enregistrement NDEF.';
      } else {
        final expected = NdefPayloadBuilder.build(
          dataType: found.dataType,
          payload: found.payload,
        );
        contentOk = NfcService.sameMessage(message, expected);
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
                    'La vérification contrôle deux choses : le tag appartient-il à IziCardOuaga (UID enregistré), et son contenu est-il celui attendu.',
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
          if (_owned != null) ...[
            const SizedBox(height: 16),
            _ResultCard(
              color:
                  _owned!
                      ? IzicardColors.statusVerified
                      : IzicardColors.statusPending,
              icon: _owned! ? Icons.verified_rounded : Icons.help_outline,
              title:
                  _owned!
                      ? '1. Appartenance : tag IziCardOuaga ✔'
                      : '1. Appartenance : tag non enregistré ✖',
              message:
                  _owned!
                      ? 'Cet UID est enregistré dans un de vos dossiers.'
                      : 'Cet UID n’est enregistré dans aucun dossier accessible avec votre compte (tag étranger, tag d’un autre client ou carte pas encore créée).',
            ),
            const SizedBox(height: 10),
            _ResultCard(
              color:
                  _contentOk == true
                      ? IzicardColors.statusVerified
                      : IzicardColors.statusPending,
              icon:
                  _contentOk == true
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
              title:
                  _contentOk == true
                      ? '2. Contenu : conforme ✔'
                      : _contentOk == false
                      ? '2. Contenu : à contrôler ✖'
                      : '2. Contenu : non comparé',
              message: _contentVerdict ?? '',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoLine(label: 'UID physique', value: _uid ?? 'Inconnu'),
                    _InfoLine(
                      label: 'Contenu lu sur le tag',
                      value: _contentRead ?? '—',
                    ),
                    if (_chip != null)
                      _InfoLine(label: 'Puce', value: _chip!),
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
