import 'package:flutter/material.dart';

import '../../../core/widgets/izi_ui.dart';

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
            return IziErrorState(
              message: 'Impossible de charger le tableau de bord. Vérifiez votre connexion.',
              onRetry: _refresh,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          IziHero(
            icon: Icons.insights_rounded,
            title: '$verified / $total cartes vérifiées',
            subtitle:
                '${batches.length} dossier(s) dont $inProgress en cours · ${clients.length} client(s)',
          ),
          const SizedBox(height: 12),
          IziProgress(value: total == 0 ? 0 : verified / total, height: 10),
          const IziSectionTitle('Cartes'),
          _StatGrid(
            children: [
              IziStat(value: '$pending', label: 'À écrire', icon: Icons.edit_note_rounded, color: context.ink.pending),
              IziStat(value: '$written', label: 'Écrites', icon: Icons.nfc_rounded, color: context.ink.written),
              IziStat(value: '$verified', label: 'Vérifiées', icon: Icons.verified_rounded, color: context.ink.verified),
              IziStat(value: '$errors', label: 'Erreurs', icon: Icons.error_outline_rounded, color: context.ink.error),
              IziStat(value: '$voided', label: 'Annulées', icon: Icons.block_rounded, color: context.ink.voided),
            ],
          ),
          const IziSectionTitle('Clients'),
          _StatGrid(
            children: [
              IziStat(value: '$activeClients', label: 'Actifs', icon: Icons.check_circle_outline_rounded, color: context.ink.verified),
              IziStat(value: '$suspended', label: 'Suspendus', icon: Icons.pause_circle_outline_rounded, color: context.ink.error),
              IziStat(value: '$expired', label: 'Expirés', icon: Icons.schedule_rounded, color: context.ink.pending),
            ],
          ),
          const IziSectionTitle('Dossiers avec des erreurs'),
          if (attention.isEmpty)
            const IziNotice(
              'Aucune erreur d’écriture en cours.',
              tone: IziTone.success,
            )
          else
            ...attention
                .take(8)
                .map(
                  (b) => Card(
                    child: ListTile(
                      onTap: () => _openBatch(b),
                      leading: Icon(
                        Icons.error_outline_rounded,
                        color: context.ink.error,
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
          const IziSectionTitle('Volume par client'),
          if (ranking.isEmpty)
            const IziNotice('Aucun dossier pour le moment.')
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
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
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

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 640 ? 3 : 2;
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
