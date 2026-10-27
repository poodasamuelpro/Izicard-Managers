import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/izicard_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/remote/tags_remote.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../batches/batch_source.dart';
import '../cards/card_picker_screen.dart';
import '../nfc/nfc_help_banner.dart';
import 'write_controller.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key, required this.profile, this.initialBatchId});

  final NfcProfile profile;
  final String? initialBatchId;

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  late final BatchRepository _batches;
  late final AppDatabase _database;
  late final WriteController _controller;
  Future<BatchList>? _batchFuture;
  bool _nfcReady = true;
  NfcBatch? _selected;
  late bool _lock;
  late bool _auto;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    final settings = AppSettingsStore.instance.value;
    _lock = settings.lockByDefault;
    _auto = settings.autoAdvance;
    _batches = BatchRepository(client);
    _database = AppDatabase();
    _controller = WriteController(
      tags: TagRepository(TagsRemote(client)),
      database: _database,
      userId: client.auth.currentUser?.id ?? '',
      confirmOverwrite: _confirmOverwrite,
    );
    _batchFuture = loadBatches(_batches).then((list) {
      final all = list.batches;
      final initial = widget.initialBatchId;
      if (initial != null) {
        final match = all.where((b) => b.id == initial);
        if (match.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _select(match.first),
          );
        }
      }
      return list;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _database.close();
    super.dispose();
  }

  Future<void> _select(NfcBatch batch) async {
    setState(() => _selected = batch);
    await _controller.load(batch);
  }

  Future<void> _pickSingle() async {
    final batch = _selected;
    if (batch == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => CardPickerScreen(
              tags: _controller.queue,
              profile: widget.profile,
              batchName: batch.name,
            ),
      ),
    );
    if (changed == true && mounted) await _controller.load(batch);
  }

  Future<void> _start() async {
    if (_lock) {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              icon: const Icon(Icons.lock_outline_rounded),
              title: const Text('Verrouillage définitif'),
              content: const Text(
                'Chaque tag vérifié sera verrouillé pour toujours : il ne pourra plus jamais être réécrit. '
                'Confirmer pour toute cette série ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Verrouiller'),
                ),
              ],
            ),
      );
      if (ok != true) return;
    }
    _controller.start(lockAfterWrite: _lock, auto: _auto);
  }

  Future<bool> _confirmOverwrite(String uid, int existingRecordCount) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                icon: const Icon(Icons.warning_amber_rounded),
                title: const Text('Tag déjà utilisé'),
                content: Text(
                  'Le tag $uid contient déjà $existingRecordCount enregistrement(s) NDEF. '
                  'La nouvelle donnée remplacera son contenu actuel. Continuer ?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Remplacer'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<bool> _confirmLeave() async {
    if (!_controller.isActive) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Quitter la série ?'),
            content: const Text(
              'Les cartes déjà vérifiées sont enregistrées. La série en cours sera arrêtée.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Rester'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Quitter'),
              ),
            ],
          ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => PopScope(
            canPop: !_controller.isActive,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final navigator = Navigator.of(context);
              if (await _confirmLeave()) {
                await _controller.finish();
                if (mounted) navigator.pop();
              }
            },
            child: Scaffold(
              appBar: AppBar(title: const Text('Écriture NFC')),
              body: SafeArea(
                child: switch (_controller.phase) {
                  SeriesPhase.idle => _setup(context),
                  SeriesPhase.finished => _summary(context),
                  _ => _run(context),
                },
              ),
            ),
          ),
    );
  }

  // ----- Préparation -----
  Widget _setup(BuildContext context) {
    return FutureBuilder<BatchList>(
      future: _batchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            text: 'Impossible de charger les dossiers.',
            onRetry: () => setState(() => _batchFuture = loadBatches(_batches)),
          );
        }
        final batches =
            (snapshot.data?.batches ?? const <NfcBatch>[])
                .where((b) => b.status != 'archived')
                .toList();
        final offline = snapshot.data?.offline ?? false;
        final controller = _controller;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            NfcHelpBanner(
              onChanged: (ready) {
                if (ready != _nfcReady && mounted)
                  setState(() => _nfcReady = ready);
              },
            ),
            if (offline)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Hors connexion : seuls les dossiers déjà téléchargés sont disponibles.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              'Dossier à encoder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (batches.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Aucun dossier disponible.'),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dossier',
                  border: OutlineInputBorder(),
                ),
                items:
                    batches
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              '${b.name} — ${b.pending + b.errors} à écrire',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (id) {
                  final batch = batches.firstWhere((b) => b.id == id);
                  _select(batch);
                },
              ),
            const SizedBox(height: 16),
            if (controller.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (controller.loadError != null)
              _Message(
                text: controller.loadError!,
                onRetry: _selected == null ? null : () => _select(_selected!),
              )
            else if (_selected != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.offline_pin_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          controller.queue.isEmpty
                              ? 'Aucune carte en attente d’écriture dans ce dossier.'
                              : '${controller.queue.length} carte(s) à écrire, lues depuis le cache de cet appareil.'
                                  '${controller.unsynced > 0 ? '\n${controller.unsynced} résultat(s) en attente de synchronisation.' : ''}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => controller.refreshFromServer(_selected!),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Mettre à jour depuis le serveur'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _auto,
                onChanged: (value) => setState(() => _auto = value),
                title: const Text('Avancement automatique'),
                subtitle: const Text(
                  'Passe seul à la carte suivante après une carte vérifiée.',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _lock,
                onChanged: (value) => setState(() => _lock = value),
                title: const Text('Verrouiller définitivement les tags'),
                subtitle: const Text(
                  'Irréversible. Appliqué seulement après une relecture réussie. Confirmation demandée.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed:
                    controller.queue.isEmpty || !_nfcReady ? null : _start,
                icon: const Icon(Icons.nfc_rounded),
                label: const Text(
                  'Démarrer la série',
                  style: TextStyle(fontSize: 17),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: controller.queue.isEmpty ? null : _pickSingle,
                icon: const Icon(Icons.looks_one_outlined),
                label: const Text(
                  'Encoder une seule carte',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ----- Série en cours -----
  Widget _run(BuildContext context) {
    final c = _controller;
    final tag = c.current;
    final total = c.queue.length;
    final (color, icon) = switch (c.phase) {
      SeriesPhase.success => (
        IzicardColors.statusVerified,
        Icons.check_circle_rounded,
      ),
      SeriesPhase.error => (IzicardColors.statusError, Icons.error_rounded),
      SeriesPhase.paused => (
        IzicardColors.statusVoid,
        Icons.pause_circle_rounded,
      ),
      _ => (IzicardColors.statusPending, Icons.nfc_rounded),
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Text(
              '${(c.index + 1).clamp(1, total)} / $total',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : c.index / total,
                minHeight: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Vérifiées : ${c.verified} · Erreurs : ${c.errors} · Passées : ${c.skipped}'
          '${c.unsynced > 0 ? ' · À synchroniser : ${c.unsynced}' : ''}',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 64),
              const SizedBox(height: 12),
              Text(
                c.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (c.phase == SeriesPhase.waiting) ...[
                const SizedBox(height: 8),
                const Text(
                  'Gardez le tag contre le dos du téléphone jusqu’au signal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
        if (tag != null) ...[
          const SizedBox(height: 14),
          Text(
            'Carte n° ${tag.sequence} — ${tag.publicId}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(tag.payload),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (c.phase == SeriesPhase.error)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
            ),
            onPressed: c.retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        if (c.phase == SeriesPhase.success && !c.autoAdvance)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
            ),
            onPressed: c.next,
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Carte suivante'),
          ),
        if (c.phase == SeriesPhase.paused)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
            ),
            onPressed: c.resume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Reprendre'),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (c.phase == SeriesPhase.waiting ||
                c.phase == SeriesPhase.success ||
                c.phase == SeriesPhase.error)
              OutlinedButton.icon(
                onPressed: c.pause,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pause'),
              ),
            if (c.phase == SeriesPhase.error || c.phase == SeriesPhase.paused)
              OutlinedButton.icon(
                onPressed: c.skip,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Passer cette carte'),
              ),
            OutlinedButton.icon(
              onPressed: () => c.finish(),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Terminer'),
            ),
          ],
        ),
      ],
    );
  }

  // ----- Résumé -----
  Widget _summary(BuildContext context) {
    final c = _controller;
    final remaining = (c.queue.length - c.index).clamp(0, c.queue.length);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.flag_rounded, size: 56, color: IzicardColors.cyan),
        const SizedBox(height: 10),
        Text(
          'Série terminée',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _Count(
              label: 'Vérifiées',
              value: c.verified,
              color: IzicardColors.statusVerified,
            ),
            _Count(
              label: 'Erreurs',
              value: c.errors,
              color: IzicardColors.statusError,
            ),
            _Count(
              label: 'Passées',
              value: c.skipped,
              color: IzicardColors.statusVoid,
            ),
            _Count(
              label: 'Restantes',
              value: remaining,
              color: IzicardColors.statusPending,
            ),
          ],
        ),
        if (c.unsynced > 0) ...[
          const SizedBox(height: 14),
          Text(
            '${c.unsynced} résultat(s) seront envoyés à la base dès que la connexion revient (écran Synchronisation).',
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Retour'),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(text, style: const TextStyle(color: IzicardColors.statusError)),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    ),
  );
}
