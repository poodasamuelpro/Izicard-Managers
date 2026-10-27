import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/local/offline_tags_dao.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/models/nfc_tag.dart';
import '../../data/remote/tags_remote.dart';
import '../../data/repositories/tag_repository.dart';
import 'single_write_screen.dart';

/// Détail d'une carte : donnée, champs, UID, historique d'écriture, et encodage de cette seule carte.
class TagDetailScreen extends StatefulWidget {
  const TagDetailScreen({
    super.key,
    required this.tag,
    required this.profile,
    this.batchName,
  });

  final NfcTagRecord tag;
  final NfcProfile profile;
  final String? batchName;

  @override
  State<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends State<TagDetailScreen> {
  late final AppDatabase _database;
  late final TagRepository _tags;
  late final OfflineTagsDao _offline;
  late final String _userId;
  late NfcTagRecord _tag;
  bool _changed = false;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _userId = client.auth.currentUser?.id ?? '';
    _database = AppDatabase();
    _tags = TagRepository(TagsRemote(client));
    _offline = OfflineTagsDao(_database);
    _tag = widget.tag;
    _refresh();
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    NfcTagRecord? fresh;
    var cached = false;
    try {
      fresh = await _tags.getTag(_tag.id).timeout(const Duration(seconds: 6));
    } catch (_) {
      fresh = await _offline.tagById(_userId, _tag.id);
      cached = fresh != null;
    }
    if (!mounted || fresh == null) return;
    setState(() {
      _tag = fresh!;
      _fromCache = cached;
    });
  }

  Future<void> _write() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => SingleWriteScreen(
              tag: _tag,
              profile: widget.profile,
              batchName: widget.batchName,
            ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _refresh();
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _tag.payload));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Donnée copiée.')));
  }

  @override
  Widget build(BuildContext context) {
    final tag = _tag;
    final color = IzicardColors.forTagStatus(tag.status);
    final canWrite = widget.profile.hasValidAccess && tag.isWritable;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Carte n° ${tag.sequence}')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  children: [
                    if (_fromCache)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Hors connexion : données du cache de cet appareil.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.tertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag.publicId,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              IzicardColors.labelForTagStatus(tag.status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.batchName != null) Text(widget.batchName!),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Donnée à encoder',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copier',
                                  onPressed: _copy,
                                  icon: const Icon(Icons.copy_rounded),
                                ),
                              ],
                            ),
                            SelectableText(tag.payload),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _Row('Numéro', '${tag.sequence}'),
                            _Row('Type de donnée', tag.dataType),
                            _Row('UID du tag', tag.uid),
                            _Row('Tentatives', '${tag.attempts}'),
                            _Row(
                              'Verrouillée',
                              tag.locked ? 'Oui (définitif)' : 'Non',
                            ),
                            _Row(
                              'Écrite le',
                              tag.writtenAt == null
                                  ? null
                                  : tag.writtenAt!
                                      .replaceFirst('T', ' ')
                                      .split('.')
                                      .first,
                            ),
                            _Row('Dernière erreur', tag.lastError),
                          ],
                        ),
                      ),
                    ),
                    if (tag.fields.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Champs de la carte',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              ...(tag.fields.entries.toList()
                                    ..sort((a, b) => a.key.compareTo(b.key)))
                                  .map(
                                    (entry) => _Row(
                                      entry.key,
                                      entry.value?.toString(),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: canWrite ? _write : null,
                      icon: const Icon(Icons.nfc_rounded),
                      label: const Text('Encoder cette carte uniquement'),
                    ),
                    if (!canWrite)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.profile.hasValidAccess
                              ? (tag.status == 'verified'
                                  ? 'Cette carte est déjà vérifiée : elle ne peut plus être réécrite.'
                                  : tag.locked
                                  ? 'Cette carte est verrouillée définitivement.'
                                  : 'Cette carte est annulée.')
                              : 'Votre accès n’est plus actif.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(value == null || value!.isEmpty ? '—' : value!),
        ),
      ],
    ),
  );
}
