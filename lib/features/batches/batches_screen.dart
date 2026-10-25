import 'package:flutter/material.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/batch_repository.dart';
import '../admin/batches/batch_create_screen.dart';
import 'batch_detail_screen.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({
    super.key,
    required this.profile,
    required this.repository,
  });

  final NfcProfile profile;
  final BatchRepository repository;

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  late Future<List<NfcBatch>> _batches;
  String _filter = 'Tous';

  @override
  void initState() {
    super.initState();
    _batches = widget.repository.listBatchStats();
  }

  Future<void> _refresh() async {
    final future = widget.repository.listBatchStats();
    setState(() => _batches = future);
    try {
      await future;
    } catch (_) {
      // Le FutureBuilder affiche l’état d’erreur ; le geste de rafraîchissement reste propre.
    }
  }

  bool get _canCreate => widget.profile.role == NfcRole.admin;

  void _openCreate() {
    if (!_canCreate) return;
    Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BatchCreateScreen(
          profile: widget.profile,
          repository: widget.repository,
        ),
      ),
    ).then((created) {
      if (created == true) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dossiers NFC')),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau dossier'),
            )
          : null,
      body: SafeArea(
        child: FutureBuilder<List<NfcBatch>>(
          future: _batches,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(onRetry: _refresh);
            }
            final batches = snapshot.data ?? const <NfcBatch>[];
            final visible = batches.where((batch) {
              if (_filter == 'Tous') return true;
              return switch (_filter) {
                'En cours' => batch.status == 'in_progress',
                'À traiter' => batch.pending > 0 || batch.errors > 0,
                'Terminés' => batch.status == 'completed',
                _ => true,
              };
            }).toList();

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                children: [
                  _SummaryHeader(count: batches.length),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Tous', 'En cours', 'À traiter', 'Terminés']
                          .map((label) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(label),
                                  selected: _filter == label,
                                  onSelected: (_) => setState(() => _filter = label),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    _EmptyBatches(
                      canCreate: _canCreate,
                      onCreate: _openCreate,
                      isFiltered: _filter != 'Tous',
                    )
                  else
                    ...visible.map((batch) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BatchCard(
                            batch: batch,
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => BatchDetailScreen(batch: batch),
                              ),
                            ),
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
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [IzicardColors.cyan, IzicardColors.blue],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const Icon(Icons.nfc_rounded, color: Colors.white, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count dossier${count == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          )),
                  const SizedBox(height: 4),
                  const Text('Suivez vos lots de production NFC',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch, required this.onTap});
  final NfcBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(batch.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(label: batch.statusLabel, status: batch.status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Metric(label: 'Total', value: batch.total),
                  _Metric(label: 'En attente', value: batch.pending),
                  _Metric(label: 'Écrites', value: batch.written),
                  _Metric(label: 'Vérifiées', value: batch.verified),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: batch.progress,
                  minHeight: 7,
                  backgroundColor: IzicardColors.cyan.withOpacity(.12),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('${(batch.progress * 100).round()} % vérifié',
                        style: theme.textTheme.bodySmall),
                  ),
                  if (batch.errors > 0)
                    Text('${batch.errors} erreur${batch.errors == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        )),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => const Color(0xFF21845A),
      'in_progress' => IzicardColors.blue,
      'archived' => Colors.grey,
      'ready' => IzicardColors.cyan,
      _ => const Color(0xFF9A6700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyBatches extends StatelessWidget {
  const _EmptyBatches({
    required this.canCreate,
    required this.onCreate,
    required this.isFiltered,
  });
  final bool canCreate;
  final VoidCallback onCreate;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Column(
          children: [
            Icon(isFiltered ? Icons.filter_alt_off_rounded : Icons.inventory_2_outlined,
                size: 48, color: IzicardColors.cyan),
            const SizedBox(height: 14),
            Text(isFiltered ? 'Aucun dossier dans ce filtre' : 'Aucun dossier pour le moment',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Essayez un autre filtre.'
                  : 'Les dossiers autorisés pour votre compte apparaîtront ici.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (canCreate && !isFiltered) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer un dossier'),
              ),
            ],
          ],
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44),
              const SizedBox(height: 12),
              const Text('Impossible de charger les dossiers.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
}
