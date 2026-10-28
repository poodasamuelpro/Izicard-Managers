import 'package:flutter/material.dart';

import '../../core/widgets/izi_ui.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/local/offline_tags_dao.dart';
import '../../data/local/pending_writes_dao.dart';
import '../../data/repositories/sync_repository.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({
    super.key,
    required this.repository,
    required this.offline,
    required this.userId,
  });
  final SyncRepository repository;
  final OfflineTagsDao offline;
  final String userId;

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  late Future<_Data> _data;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_Data> _load() async => _Data(
    items: await widget.repository.items(),
    batches: await widget.offline.downloadedBatches(widget.userId),
  );

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _data = next);
    await next;
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final result = await widget.repository.syncPending();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _data = _load();
    });
    final text =
        result.blocked
            ? 'Session différente de celle qui a créé ces opérations : reconnectez-vous avec le bon compte.'
            : result.sent == 0 && result.rejected == 0
            ? 'Aucune opération synchronisée. La file est conservée.'
            : '${result.sent} synchronisée(s)${result.rejected > 0 ? ' · ${result.rejected} refusée(s) par la base' : ''}.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _discard(PendingWrite item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Abandonner cette opération ?'),
            content: const Text(
              'Le résultat d’écriture de cette carte ne sera jamais envoyé à la base.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Abandonner'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await widget.repository.discard(item.id);
      await _refresh();
    }
  }

  Future<void> _removeBatch(OfflineBatchInfo info) async {
    await widget.offline.removeBatch(widget.userId, info.batch.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Synchronisation')),
    body: SafeArea(
      child: FutureBuilder<_Data>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return IziErrorState(
              message: 'Impossible de lire les opérations enregistrées sur cet appareil.',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data!;
          final waiting = data.items.where((item) => !item.permanent).length;
          final rejected = data.items.length - waiting;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_queue_rounded, size: 34),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            data.items.isEmpty
                                ? 'Tout est synchronisé.'
                                : '$waiting en attente de connexion${rejected > 0 ? ' · $rejected refusée(s) par la base' : ''}.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon:
                      _syncing
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.sync_rounded),
                  label: Text(
                    _syncing ? 'Synchronisation…' : 'Synchroniser maintenant',
                  ),
                ),
                const SizedBox(height: 18),
                if (data.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: IziEmptyState(
                      icon: Icons.cloud_done_outlined,
                      title: 'Tout est synchronisé',
                      message: 'Aucune opération en attente sur cet appareil.',
                    ),
                  )
                else
                  ...data.items.map(
                    (item) => Card(
                      child: ListTile(
                        leading: Icon(
                          item.permanent
                              ? Icons.error_outline_rounded
                              : Icons.schedule_rounded,
                          color:
                              item.permanent
                                  ? context.ink.error
                                  : context.ink.pending,
                        ),
                        title: Text(
                          'Carte ${item.tagId.length > 8 ? item.tagId.substring(0, 8) : item.tagId} · ${IzicardColors.labelForTagStatus(item.status)}',
                        ),
                        subtitle: Text(
                          item.permanent
                              ? 'Refusée : ${item.syncError ?? 'raison inconnue'}'
                              : 'Tentative ${item.attempts}',
                        ),
                        isThreeLine: item.permanent,
                        trailing:
                            item.permanent
                                ? PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'retry') {
                                      await widget.repository.retry(item.id);
                                      await _refresh();
                                    } else {
                                      await _discard(item);
                                    }
                                  },
                                  itemBuilder:
                                      (_) => const [
                                        PopupMenuItem(
                                          value: 'retry',
                                          child: Text('Réessayer'),
                                        ),
                                        PopupMenuItem(
                                          value: 'discard',
                                          child: Text('Abandonner'),
                                        ),
                                      ],
                                )
                                : null,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                Text(
                  'Dossiers téléchargés (hors-ligne)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (data.batches.isEmpty)
                  const Text(
                    'Aucun dossier téléchargé. Ouvrez un dossier puis choisissez « Télécharger pour le hors-ligne ».',
                  )
                else
                  ...data.batches.map(
                    (info) => Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.offline_pin_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(info.batch.name),
                        subtitle: Text(
                          '${info.tagCount} carte(s) · téléchargé le ${info.syncedAt.toLocal().toString().substring(0, 16)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Supprimer de cet appareil',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _removeBatch(info),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Data {
  const _Data({required this.items, required this.batches});
  final List<PendingWrite> items;
  final List<OfflineBatchInfo> batches;
}
