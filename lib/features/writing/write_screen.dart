import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/remote/tags_remote.dart';
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
  Future<List<NfcBatch>>? _batchFuture;
  NfcBatch? _selectedBatch;
  bool _lockAfterWrite = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _batches = BatchRepository(client);
    _database = AppDatabase();
    _controller = WriteController(
      tags: TagRepository(TagsRemote(client)),
      database: _database,
      userId: client.auth.currentUser?.id ?? '',
    );
    _batchFuture = _batches.listBatchStats();
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  Future<void> _selectBatch(NfcBatch batch) async {
    setState(() => _selectedBatch = batch);
    await _controller.load(batch.id);
    if (mounted) setState(() {});
  }

  Future<void> _write() async {
    await _controller.writeCurrent(lockAfterWrite: _lockAfterWrite);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Écriture NFC')),
      body: SafeArea(
        child: FutureBuilder<List<NfcBatch>>(
          future: _batchFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _ErrorState(message: snapshot.error.toString());
            final batches = snapshot.data ?? const <NfcBatch>[];
            return _content(context, batches);
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<NfcBatch> batches) {
    final result = _controller.currentResult;
    final tag = _controller.currentTag;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Choisir un dossier', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (batches.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Aucun dossier disponible.')))
        else
          DropdownButtonFormField<NfcBatch>(
            value: _selectedBatch,
            decoration: const InputDecoration(labelText: 'Dossier', border: OutlineInputBorder()),
            items: batches.map((batch) => DropdownMenuItem(value: batch, child: Text(batch.name))).toList(),
            onChanged: (batch) {
              if (batch != null) _selectBatch(batch);
            },
          ),
        const SizedBox(height: 18),
        if (_selectedBatch != null) ...[
          _BatchSummary(batch: _selectedBatch!),
          const SizedBox(height: 18),
          if (_controller.loading)
            const Center(child: CircularProgressIndicator())
          else if (_controller.error != null)
            _ErrorState(message: _controller.error!)
          else if (tag == null)
            Card(
              color: IzicardColors.paleCyan,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(_controller.items.isEmpty ? 'Aucune carte en attente d’écriture.' : 'Toutes les cartes restantes ont été traitées.'),
              ),
            )
          else ...[
            _ProgressHeader(index: _controller.currentIndex + 1, total: _controller.items.length),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Carte ${tag.sequence}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Identifiant : ${tag.publicId}'),
                  Text('Type : ${tag.dataType}'),
                  const SizedBox(height: 12),
                  const Text('Payload attendu', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  SelectableText(tag.payload),
                  if (result?.message != null) ...[
                    const SizedBox(height: 16),
                    _StatusMessage(status: result!.status, message: result.message!),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _lockAfterWrite,
              onChanged: result?.status == 'writing' ? null : (value) => setState(() => _lockAfterWrite = value),
              title: const Text('Verrouiller le tag après vérification'),
              subtitle: const Text('Cette opération est définitive sur les tags compatibles.'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _controller.processing ? null : _write,
              icon: Icon(_controller.processing ? Icons.hourglass_top_rounded : Icons.nfc_rounded),
              label: Text(_controller.processing ? 'Lecture du tag…' : 'Approcher le tag'),
            ),
            if (result?.status == 'error') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _controller.processing ? null : () => setState(_controller.retryCurrent),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _controller.processing ? null : () => setState(_controller.skipCurrent),
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Passer cette carte'),
            ),
          ],
        ],
      ],
    );
  }
}

class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.batch});
  final NfcBatch batch;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined, color: IzicardColors.cyan),
            const SizedBox(width: 12),
            Expanded(child: Text('${batch.statusLabel} · ${batch.total} cartes')),
            Text('${(batch.progress * 100).round()} %'),
          ]),
        ),
      );
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.index, required this.total});
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progression', style: Theme.of(context).textTheme.titleMedium),
          Text('$index / $total'),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: total == 0 ? 0 : index / total, minHeight: 8),
      ]);
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.status, required this.message});
  final String status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = status == 'verified' ? IzicardColors.success : status == 'error' ? Colors.red : IzicardColors.cyan;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(status == 'verified' ? Icons.check_circle : Icons.info_outline, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      );
}
