import 'package:flutter/material.dart';

import '../../data/local/pending_writes_dao.dart';
import '../../data/repositories/sync_repository.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key, required this.repository});
  final SyncRepository repository;

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  late Future<List<PendingWrite>> _pending;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _pending = widget.repository.queue.pending(limit: 200);
  }

  Future<void> _refresh() async {
    final next = widget.repository.queue.pending(limit: 200);
    setState(() => _pending = next);
    await next;
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final result = await widget.repository.syncPending();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _pending = widget.repository.queue.pending(limit: 200);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.sent == 0
          ? 'Aucune opération synchronisée. La file est conservée.'
          : '${result.sent} opération(s) synchronisée(s).')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Synchronisation')),
        body: SafeArea(
          child: FutureBuilder<List<PendingWrite>>(
            future: _pending,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Impossible de lire la file locale.'));
              }
              final items = snapshot.data ?? const <PendingWrite>[];
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(children: [
                          const Icon(Icons.cloud_queue_rounded, size: 34),
                          const SizedBox(width: 14),
                          Expanded(child: Text(
                            items.isEmpty
                                ? 'Tout est synchronisé.'
                                : '${items.length} opération(s) attendent une connexion.',
                            style: Theme.of(context).textTheme.titleMedium,
                          )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _syncing ? null : _sync,
                      icon: _syncing
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync_rounded),
                      label: Text(_syncing ? 'Synchronisation…' : 'Synchroniser maintenant'),
                    ),
                    const SizedBox(height: 18),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 38),
                        child: Center(child: Text('Aucune opération en attente.')),
                      )
                    else
                      ...items.map((item) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.nfc_rounded),
                              title: Text('Carte ${item.tagId}'),
                              subtitle: Text('${item.status} · tentative ${item.attempts}'),
                              trailing: item.error == null
                                  ? const Icon(Icons.schedule_rounded)
                                  : const Icon(Icons.error_outline_rounded),
                            ),
                          )),
                  ],
                ),
              );
            },
          ),
        ),
      );
}
