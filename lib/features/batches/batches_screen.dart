import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';
import '../../core/theme/izicard_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/batch_repository.dart';
import '../admin/batches/batch_create_screen.dart';
import '../import/import_screen.dart';
import 'batch_detail_screen.dart';
import 'batch_source.dart';

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
  late Future<BatchList> _batches;
  late final RealtimeChannel _realtime;
  Timer? _realtimeDebounce;
  String _filter = 'Tous';

  @override
  void initState() {
    super.initState();
    _batches = loadBatches(widget.repository);
    final client = Supabase.instance.client;
    _realtime =
        client
            .channel(
              'izicard-mobile-batches-${client.auth.currentUser?.id ?? 'anonymous'}',
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: AppConstants.nfcSchema,
              table: 'nfc_batches',
              callback: (_) => _scheduleRealtimeRefresh(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: AppConstants.nfcSchema,
              table: 'nfc_tags',
              callback: (_) => _scheduleRealtimeRefresh(),
            )
            .subscribe();
  }

  Future<void> _refresh() async {
    final future = loadBatches(widget.repository);
    setState(() => _batches = future);
    try {
      await future;
    } catch (_) {}
  }

  void _scheduleRealtimeRefresh() {
    if (!mounted) return;
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) unawaited(_refresh());
    });
  }

  bool _offline = false;

  bool get _canCreate =>
      !_offline &&
      (widget.profile.role == NfcRole.admin ||
          (widget.profile.role == NfcRole.client &&
              widget.profile.canCreateBatches &&
              widget.profile.clientId != null));

  void _openCreate() {
    if (!_canCreate) return;
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder:
                (_) => BatchCreateScreen(
                  profile: widget.profile,
                  repository: widget.repository,
                ),
          ),
        )
        .then((created) {
          if (created == true) _refresh();
        });
  }

  void _openImport(NfcBatch batch) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => ImportScreen(
              profile: widget.profile,
              repository: widget.repository,
              initialBatchId: batch.id,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    Supabase.instance.client.removeChannel(_realtime);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dossiers NFC')),
    floatingActionButton:
        _canCreate
            ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau dossier'),
            )
            : null,
    body: SafeArea(
      child: FutureBuilder<BatchList>(
        future: _batches,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _LoadError(onRetry: _refresh);
          final batches = snapshot.data?.batches ?? const <NfcBatch>[];
          final offline = snapshot.data?.offline ?? false;
          if (offline != _offline) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _offline != offline)
                setState(() => _offline = offline);
            });
          }
          final visible =
              batches
                  .where(
                    (batch) =>
                        _filter == 'Tous' ||
                        switch (_filter) {
                          'En cours' => batch.status == 'in_progress',
                          'À traiter' => batch.pending > 0 || batch.errors > 0,
                          'Terminés' => batch.status == 'completed',
                          _ => true,
                        },
                  )
                  .toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ResponsiveContent(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isGrid = constraints.maxWidth >= 860;
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (offline)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Hors connexion : dossiers téléchargés sur cet appareil. Tirez pour réessayer.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      _SummaryHeader(count: batches.length),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              ['Tous', 'En cours', 'À traiter', 'Terminés']
                                  .map(
                                    (label) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(label),
                                        selected: _filter == label,
                                        onSelected:
                                            (_) =>
                                                setState(() => _filter = label),
                                      ),
                                    ),
                                  )
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
                      else if (isGrid)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children:
                              visible
                                  .map(
                                    (batch) => SizedBox(
                                      width: cardWidth,
                                      child: _BatchCard(
                                        batch: batch,
                                        onTap:
                                            () => Navigator.of(
                                              context,
                                            ).push<void>(
                                              MaterialPageRoute<void>(
                                                builder:
                                                    (_) => BatchDetailScreen(
                                                      batch: batch,
                                                      profile: widget.profile,
                                                      repository:
                                                          widget.repository,
                                                      onImport:
                                                          () => _openImport(
                                                            batch,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        )
                      else
                        ...visible.map(
                          (batch) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BatchCard(
                              batch: batch,
                              onTap:
                                  () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => BatchDetailScreen(
                                            batch: batch,
                                            profile: widget.profile,
                                            repository: widget.repository,
                                            onImport: () => _openImport(batch),
                                          ),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: context.ink.hero),
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
              Text(
                '$count dossier${count == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Suivez vos lots de production NFC',
                style: TextStyle(color: Colors.white),
              ),
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
                    child: Text(
                      batch.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(batch.progress * 100).round()} % vérifié',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (batch.errors > 0)
                    Text(
                      '${batch.errors} erreur${batch.errors == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final color = switch (status) {
      'completed' => dark ? const Color(0xFF6AD99A) : const Color(0xFF146C43),
      'in_progress' => dark ? const Color(0xFF8ACFFF) : const Color(0xFF006EAA),
      'archived' => scheme.onSurfaceVariant,
      'ready' => dark ? const Color(0xFF5AD5ED) : const Color(0xFF007F9E),
      _ => dark ? const Color(0xFFFFC078) : const Color(0xFF8B4A00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(dark ? .16 : .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
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
        Icon(
          isFiltered
              ? Icons.filter_alt_off_rounded
              : Icons.inventory_2_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          isFiltered
              ? 'Aucun dossier dans ce filtre'
              : 'Aucun dossier pour le moment',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
