import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/izicard_colors.dart';
import '../../core/widgets/izi_ui.dart';
import '../../core/widgets/responsive_content.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/models/nfc_tag.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/tags_remote.dart';
import '../../data/repositories/offline_repository.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../services/export/csv_exporter.dart';
import '../cards/tag_detail_screen.dart';
import '../verify/verify_tag_screen.dart';
import '../writing/write_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({
    super.key,
    required this.batch,
    required this.profile,
    required this.repository,
    required this.onImport,
  });

  final NfcBatch batch;
  final NfcProfile profile;
  final BatchRepository repository;
  final VoidCallback onImport;

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  static const _pageSize = 50;
  static const _filters = <String?, String>{
    null: 'Toutes',
    'pending': 'À écrire',
    'written': 'Écrites',
    'verified': 'Vérifiées',
    'error': 'Erreurs',
    'void': 'Annulées',
  };

  late final TagRepository _tags;
  late final AppDatabase _database;
  late final OfflineRepository _offline;
  late NfcBatch _batch;
  bool _downloading = false;
  bool _available = false;
  final _searchController = TextEditingController();
  Timer? _debounce;
  final List<NfcTagRecord> _items = [];
  String? _status;
  bool _loading = false;
  int _generation = 0;
  bool _hasMore = true;
  String? _error;
  bool _exporting = false;
  bool _offlineMode = false;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
    final client = Supabase.instance.client;
    _userId = client.auth.currentUser?.id ?? '';
    _tags = TagRepository(TagsRemote(client));
    _database = AppDatabase();
    _offline = OfflineRepository(
      database: _database,
      remote: TagsRemote(client),
      userId: client.auth.currentUser?.id ?? '',
    );
    _offline.hasBatch(_batch.id).then((value) {
      if (mounted) setState(() => _available = value);
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _database.close();
    super.dispose();
  }

  bool get _canWork =>
      _batch.status != 'archived' && widget.profile.hasValidAccess;

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _offlineMode = false;
      _items.clear();
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await Future.wait([_loadMore(), _refreshStats()]);
  }

  Future<void> _refreshStats() async {
    try {
      final all = await widget.repository.listBatchStats();
      final fresh = all.where((b) => b.id == _batch.id);
      if (fresh.isNotEmpty && mounted) setState(() => _batch = fresh.first);
    } catch (_) {
      // Hors connexion : compteurs recalculés depuis le cache local si le dossier est téléchargé.
      try {
        final local = (await _offline.offlineBatches()).where(
          (b) => b.id == _batch.id,
        );
        if (local.isNotEmpty && mounted) setState(() => _batch = local.first);
      } catch (_) {
        // Les compteurs précédents restent affichés.
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      List<NfcTagRecord> page;
      var offline = _offlineMode;
      if (offline) {
        page = await _localPage();
      } else {
        try {
          page = await _tags.page(
            batchId: _batch.id,
            status: _status,
            search: _searchController.text,
            offset: _items.length,
            limit: _pageSize,
          );
        } catch (remoteError) {
          if (!await _offline.hasBatch(_batch.id)) rethrow;
          // Réseau indisponible : on bascule sur le cache local, depuis le début de la liste.
          offline = true;
          _items.clear();
          page = await _localPage();
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _offlineMode = offline;
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<List<NfcTagRecord>> _localPage() => _offline.dao.page(
    userId: _userId,
    batchId: _batch.id,
    status: _status,
    search: _searchController.text,
    offset: _items.length,
    limit: _pageSize,
  );

  Future<void> _openTag(NfcTagRecord tag) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => TagDetailScreen(
              tag: tag,
              profile: widget.profile,
              batchName: _batch.name,
            ),
      ),
    );
    if (changed == true && mounted) await _reload();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      List<NfcTagRecord> all;
      try {
        all = await _tags.all(_batch.id);
      } catch (_) {
        if (!await _offline.hasBatch(_batch.id)) rethrow;
        all = await _offline.dao.allTags(_userId, _batch.id);
      }
      if (all.isEmpty) {
        _snack('Ce dossier ne contient aucune carte.');
      } else {
        final count = await CsvExporter.share(
          batchName: _batch.name,
          tags: all,
        );
        _snack('$count ligne(s) exportée(s).');
      }
    } catch (error) {
      _snack(
        'Export impossible : ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await _refreshStats();
      final count = await _offline.downloadBatch(_batch);
      if (mounted) setState(() => _available = true);
      _snack(
        '$count carte(s) téléchargée(s) : le dossier est utilisable hors connexion.',
      );
    } catch (error) {
      _snack(
        'Téléchargement impossible : ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _toggleArchive() async {
    final archived = _batch.status != 'archived';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: Icon(
              archived ? Icons.archive_outlined : Icons.unarchive_outlined,
            ),
            title: Text(
              archived ? 'Archiver le dossier ?' : 'Réactiver le dossier ?',
            ),
            content: Text(
              archived
                  ? 'Le dossier sera conservé dans l’historique et aucune nouvelle écriture ou import ne sera autorisé.'
                  : 'Le dossier redeviendra disponible selon son état de cartes actuel.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(archived ? 'Archiver' : 'Réactiver'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.archiveBatch(
        batchId: _batch.id,
        archived: archived,
      );
      await _reload();
      _snack(archived ? 'Dossier archivé.' : 'Dossier réactivé.');
    } catch (error) {
      _snack(
        'Opération impossible : ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _showHistory() async {
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Historique du dossier'),
            content: SizedBox(
              width: 520,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: widget.repository.listAudit(
                  entity: 'batch',
                  entityId: _batch.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError)
                    return const Text('Historique indisponible.');
                  final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (rows.isEmpty)
                    return const Text(
                      'Aucun événement enregistré pour ce dossier.',
                    );
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final details = row['details'];
                      return ListTile(
                        dense: true,
                        title: Text(row['action']?.toString() ?? 'Événement'),
                        subtitle: Text('${row['at'] ?? ''}\n${details ?? ''}'),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du dossier')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ResponsiveContent(
            maxWidth: 1240,
            padding: EdgeInsets.zero,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (_offlineMode)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: IziNotice(
                      'Cartes et compteurs du cache de cet appareil.',
                      tone: IziTone.warning,
                      icon: Icons.cloud_off_rounded,
                      title: 'Hors connexion',
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _batch.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      status: _batch.status,
                      label: _batch.statusLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                IziProgress(value: _batch.progress, height: 10),
                const SizedBox(height: 6),
                Text(
                  '${(_batch.progress * 100).round()} % des cartes vérifiées',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 640 ? 5 : 3;
                    final width =
                        (constraints.maxWidth - 8 * (columns - 1)) / columns;
                    Widget cell(Widget child) => SizedBox(width: width, child: child);
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        cell(IziStat(value: '${_batch.total}', label: 'Total', icon: Icons.layers_outlined, color: theme.colorScheme.onSurface)),
                        cell(IziStat(value: '${_batch.pending}', label: 'À écrire', icon: Icons.edit_note_rounded, color: context.ink.pending)),
                        cell(IziStat(value: '${_batch.written}', label: 'Écrites', icon: Icons.nfc_rounded, color: context.ink.written)),
                        cell(IziStat(value: '${_batch.verified}', label: 'Vérifiées', icon: Icons.verified_rounded, color: context.ink.verified)),
                        cell(IziStat(value: '${_batch.errors}', label: 'Erreurs', icon: Icons.error_outline_rounded, color: context.ink.error)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_canWork)
                      FilledButton.icon(
                        onPressed: widget.onImport,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Importer / saisir'),
                      ),
                    if (_canWork)
                      FilledButton.icon(
                        onPressed:
                            () => Navigator.of(context)
                                .push<void>(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => WriteScreen(
                                          profile: widget.profile,
                                          initialBatchId: _batch.id,
                                        ),
                                  ),
                                )
                                .then((_) => _reload()),
                        icon: const Icon(Icons.nfc_rounded),
                        label: const Text('Écrire les cartes'),
                      ),
                    OutlinedButton.icon(
                      onPressed:
                          () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const VerifyTagScreen(),
                            ),
                          ),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Vérifier un tag'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _downloading ? null : _download,
                      icon:
                          _downloading
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                _available
                                    ? Icons.offline_pin_rounded
                                    : Icons.download_for_offline_outlined,
                              ),
                      label: Text(
                        _available
                            ? 'Mettre à jour hors-ligne'
                            : 'Télécharger pour le hors-ligne',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon:
                          _exporting
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.download_rounded),
                      label: const Text('Exporter en CSV'),
                    ),
                    if (widget.profile.role == NfcRole.admin)
                      OutlinedButton.icon(
                        onPressed: _toggleArchive,
                        icon: Icon(
                          _batch.status == 'archived'
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        label: Text(
                          _batch.status == 'archived'
                              ? 'Réactiver'
                              : 'Archiver',
                        ),
                      ),
                    if (widget.profile.role == NfcRole.admin)
                      OutlinedButton.icon(
                        onPressed: _showHistory,
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Historique'),
                      ),
                  ],
                ),
                const IziSectionTitle('Cartes du dossier'),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Identifiant, UID, code, référence…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _filters.entries
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(entry.value),
                                  selected: _status == entry.key,
                                  onSelected: (_) {
                                    _status = entry.key;
                                    _reload();
                                  },
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  _InlineError(message: _error!, onRetry: _loadMore)
                else if (_items.isEmpty && !_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: IziEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucune carte',
                      message: 'Aucune carte ne correspond à ce filtre ou à cette recherche.',
                    ),
                  )
                else
                  ..._items.map(
                    (tag) => _TagTile(tag: tag, onTap: () => _openTag(tag)),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!_loading &&
                    _hasMore &&
                    _error == null &&
                    _items.isNotEmpty)
                  Center(
                    child: TextButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Charger plus de cartes'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({required this.tag, required this.onTap});
  final NfcTagRecord tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = IzicardColors.forTagStatus(tag.status);
    final detail = <String>[
      if (tag.payload.isNotEmpty)
        tag.payload.length > 70
            ? '${tag.payload.substring(0, 69)}…'
            : tag.payload,
      if (tag.uid != null && tag.uid!.isNotEmpty) 'UID ${tag.uid}',
    ].join('\n');
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Text(
            '${tag.sequence}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(tag.publicId, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.isNotEmpty)
              Text(detail, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (tag.lastError != null && tag.lastError!.isNotEmpty)
              Text(
                tag.lastError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        isThreeLine: detail.contains('\n') || (tag.lastError ?? '').isNotEmpty,
        trailing: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Text(
              IzicardColors.labelForTagStatus(tag.status),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      IziNotice(message, tone: IziTone.error),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer'),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final color = switch (status) {
      'completed' => dark ? const Color(0xFF6AD99A) : const Color(0xFF146C43),
      'in_progress' => dark ? const Color(0xFF8ACFFF) : const Color(0xFF006EAA),
      'ready' => dark ? const Color(0xFF5AD5ED) : const Color(0xFF007F9E),
      'archived' => scheme.onSurfaceVariant,
      _ => dark ? const Color(0xFFFFC078) : const Color(0xFF8B4A00),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
