import 'package:flutter/material.dart';

import '../../core/widgets/izi_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/nfc_profile.dart';
import '../../data/remote/tags_remote.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../cards/single_write_screen.dart';
import '../nfc/nfc_help_banner.dart';

/// Écriture d'une seule carte, sans préparer de dossier à la main.
/// La carte est ENREGISTRÉE dans la base (dossier automatique « Cartes uniques — … »),
/// puis écrite et vérifiée par l'écran d'écriture d'une carte, qui enregistre aussi le résultat.
class QuickWriteScreen extends StatefulWidget {
  const QuickWriteScreen({
    super.key,
    required this.profile,
    required this.repository,
  });

  final NfcProfile profile;
  final BatchRepository repository;

  @override
  State<QuickWriteScreen> createState() => _QuickWriteScreenState();
}

class _QuickWriteScreenState extends State<QuickWriteScreen> {
  static const _types = <String, String>{
    'url': 'Lien web',
    'text': 'Texte',
    'phone': 'Téléphone',
    'email': 'Email',
  };

  final _value = TextEditingController();
  String _type = 'url';
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  /// (code du format, ligne envoyée à nfc_import_rows) selon le type choisi.
  (String, Map<String, dynamic>) _spec(String raw) {
    switch (_type) {
      case 'phone':
        return ('custom_phone', {'phone': raw});
      case 'email':
        return (
          'custom_url',
          {'_payload': raw.startsWith('mailto:') ? raw : 'mailto:$raw'},
        );
      case 'text':
        return ('custom_text', {'_payload': raw});
      default:
        final withScheme =
            raw.startsWith('http://') || raw.startsWith('https://')
                ? raw
                : 'https://$raw';
        return ('custom_url', {'_payload': withScheme});
    }
  }

  Future<void> _prepareAndWrite() async {
    final raw = _value.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _ok = false;
        _message = 'Saisissez d’abord la donnée à écrire.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repository = widget.repository;
      final (formatCode, row) = _spec(raw);
      final title = 'Cartes uniques — ${_types[_type]}';

      final formats =
          (await repository.listActiveFormats())
              .where((format) => format.code == formatCode)
              .toList();
      if (formats.isEmpty) {
        throw Exception('Le format « $formatCode » n’est pas disponible.');
      }
      final format = formats.first;

      final clientId =
          widget.profile.role == NfcRole.admin
              ? await repository.ensureInternalClient()
              : widget.profile.clientId;
      if (clientId == null) throw Exception('Aucun client lié à ce compte.');

      final existing =
          (await repository.listBatchStats())
              .where(
                (batch) =>
                    batch.clientId == clientId &&
                    batch.name == title &&
                    batch.status != 'archived',
              )
              .toList();
      final batchId =
          existing.isNotEmpty
              ? existing.first.id
              : await repository.createBatch(
                clientId: clientId,
                formatId: format.id,
                name: title,
                quantity: 0,
                dataType: format.defaultDataType,
                lockAfterWrite: false,
              );

      await repository.importRows(
        batchId: batchId,
        rows: [row],
        filename: 'carte unique',
      );

      final tags = await TagRepository(
        TagsRemote(Supabase.instance.client),
      ).listWritableTags(batchId);
      if (tags.isEmpty) {
        throw Exception('La carte n’a pas pu être enregistrée (donnée refusée).');
      }
      tags.sort((a, b) => a.sequence.compareTo(b.sequence));
      final tag = tags.last;

      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder:
              (_) => SingleWriteScreen(
                tag: tag,
                profile: widget.profile,
                batchName: title,
              ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _ok = changed == true;
        _message =
            changed == true
                ? 'Carte écrite et enregistrée dans le dossier « $title ».'
                : 'Carte enregistrée dans « $title » mais pas encore écrite : retrouvez-la dans ce dossier pour l’écrire.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Écrire une seule carte')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const NfcHelpBanner(),
                const IziHero(
                  icon: Icons.nfc_rounded,
                  title: 'Une carte, enregistrée',
                  subtitle:
                      'Elle est classée dans un dossier « Cartes uniques », puis écrite. Connexion requise.',
                ),
                const IziSectionTitle('Contenu de la carte'),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type de donnée',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items:
                      _types.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged:
                      _busy ? null : (value) => setState(() => _type = value!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _value,
                  enabled: !_busy,
                  keyboardType:
                      _type == 'phone'
                          ? TextInputType.phone
                          : _type == 'email'
                          ? TextInputType.emailAddress
                          : _type == 'url'
                          ? TextInputType.url
                          : TextInputType.multiline,
                  maxLines: _type == 'text' ? 4 : 1,
                  decoration: InputDecoration(labelText: _types[_type]),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  IziNotice(
                    _message!,
                    tone: _ok ? IziTone.success : IziTone.warning,
                    title: _ok ? 'Succès' : 'À savoir',
                  ),
                ],
              ],
            ),
          ),
          IziBottomBar(
            child: FilledButton.icon(
              onPressed: _busy ? null : _prepareAndWrite,
              icon:
                  _busy
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.nfc_rounded),
              label: Text(_busy ? 'Préparation…' : 'Enregistrer et écrire'),
            ),
          ),
        ],
      ),
    ),
  );
}
