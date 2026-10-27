import 'package:flutter/material.dart';

import '../../../core/theme/izicard_colors.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../data/models/nfc_batch.dart';
import '../../../data/models/nfc_client.dart';
import '../../../data/models/nfc_profile.dart';
import '../../../data/repositories/batch_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../../batches/batch_detail_screen.dart';
import '../../import/import_screen.dart';

class _DashboardData {
  const _DashboardData(this.clients, this.batches);
  final List<NfcClient> clients;
  final List<NfcBatch> batches;
}

/// Vue d'ensemble administrateur : clients, dossiers et avancement global des cartes.
/// Tout est calculé à partir des listes que la RLS autorise ; rien n'est recalculé côté règles métier.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.profile,
    required this.repository,
    required this.clients,
  });

  final NfcProfile profile;
  final BatchRepository repository;
  final ClientRepository clients;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<_DashboardData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.clients.listClients(),
      widget.repository.listBatchStats(),
    ]);
    return _DashboardData(
      results[0] as List<NfcClient>,
      results[1] as List<NfcBatch>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _data = next);
    try {
      await next;
    } catch (_) {}
  }

  void _openBatch(NfcBatch batch) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder:
                (_) => BatchDetailScreen(
                  batch: batch,
                  profile: widget.profile,
                  repository: widget.repository,
                  onImport:
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => ImportScreen(
                                profile: widget.profile,
                                repository: widget.repository,
                                initialBatchId: batch.id,
                              ),
                        ),
                      ),
                ),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tableau de bord')),
    body: SafeArea(
      child: FutureBuilder<_DashboardData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 44),
                    const SizedBox(height: 12),
                    const Text(
                      'Impossible de charger le tableau de bord.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _content(context, snapshot.data!),
          );
        },
      ),
    ),
  );

  Widget _content(BuildContext context, _DashboardData data) {
    final theme = Theme.of(context);
    final clients = data.clients;
    final batches = data.batches;
    final activeClients = clients.where((c) => c.active && !c.isExpired).length;
    final suspended = clients.where((c) => !c.active).length;
    final expired = clients.where((c) => c.active && c.isExpired).length;
    int sum(int Function(NfcBatch) pick) =>
        batches.fold<int>(0, (a, b) => a + pick(b));
    final total = sum((b) => b.total);
    final pending = sum((b) => b.pending);
    final written = sum((b) => b.written);
    final verified = sum((b) => b.verified);
    final errors = sum((b) => b.errors);
    final voided = sum((b) => b.voided);
    final attention =
        batches.where((b) => b.errors > 0 && b.status != 'archived').toList()
          ..sort((a, b) => b.errors.compareTo(a.errors));
    final inProgress = batches.where((b) => b.status == 'in_progress').length;
    final nameById = {for (final c in clients) c.id: c.name};
    final perClient = <String, ({int batches, int total, int verified})>{};
    for (final b in batches) {
      final current =
          perClient[b.clientId] ?? (batches: 0, total: 0, verified: 0);
      perClient[b.clientId] = (
        batches: current.batches + 1,
        total: current.total + b.total,
        verified: current.verified + b.verified,
      );
    }
    final ranking =
        perClient.entries.toList()
          ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return ResponsiveContent(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007F9E), Color(0xFF006EAA)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$verified / $total cartes vérifiées',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : verified / total,
                    minHeight: 9,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${batches.length} dossier(s) dont $inProgress en cours · ${clients.length} client(s)',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Cartes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tile('À écrire', pending, IzicardColors.statusPending),
              _Tile('Écrites', written, IzicardColors.statusWritten),
              _Tile('Vérifiées', verified, IzicardColors.statusVerified),
              _Tile('Erreurs', errors, IzicardColors.statusError),
              _Tile('Annulées', voided, IzicardColors.statusVoid),
            ],
          ),
          const SizedBox(height: 18),
          Text('Clients', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tile('Actifs', activeClients, IzicardColors.statusVerified),
              _Tile('Suspendus', suspended, IzicardColors.statusError),
              _Tile('Expirés', expired, IzicardColors.statusPending),
            ],
          ),
          const SizedBox(height: 22),
          Text('Dossiers avec des erreurs', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (attention.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucune erreur d’écriture en cours.'),
              ),
            )
          else
            ...attention
                .take(8)
                .map(
                  (b) => Card(
                    child: ListTile(
                      onTap: () => _openBatch(b),
                      leading: const Icon(
                        Icons.error_outline_rounded,
                        color: IzicardColors.statusError,
                      ),
                      title: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${nameById[b.clientId] ?? 'Client inconnu'} · ${b.errors} erreur(s) · ${b.pending} à écrire',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
          const SizedBox(height: 22),
          Text('Volume par client', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (ranking.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun dossier pour le moment.'),
              ),
            )
          else
            ...ranking.take(10).map((entry) {
              final stats = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nameById[entry.key] ?? 'Client inconnu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${stats.batches} dossier(s)',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value:
                              stats.total == 0
                                  ? 0
                                  : stats.verified / stats.total,
                          minHeight: 7,
                          backgroundColor: IzicardColors.cyan.withOpacity(.12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${stats.verified} / ${stats.total} cartes vérifiées',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 96),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
