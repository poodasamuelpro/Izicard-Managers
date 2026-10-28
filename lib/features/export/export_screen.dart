import 'package:flutter/material.dart';

import '../../core/widgets/izi_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/remote/tags_remote.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../services/export/csv_exporter.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.repository});
  final BatchRepository repository;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late Future<List<NfcBatch>> _batches;
  late final TagRepository _tags;
  String? _busyId;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _tags = TagRepository(TagsRemote(Supabase.instance.client));
    _batches = widget.repository.listBatchStats();
  }

  Future<void> _export(NfcBatch batch) async {
    setState(() {
      _busyId = batch.id;
      _message = null;
    });
    try {
      final tags = await _tags.all(batch.id);
      if (tags.isEmpty) {
        setState(() {
          _message = 'Ce dossier ne contient aucune carte à exporter.';
          _messageIsError = true;
        });
        return;
      }
      final count = await CsvExporter.share(batchName: batch.name, tags: tags);
      setState(() {
        _message = '$count ligne(s) exportée(s).';
        _messageIsError = false;
      });
    } catch (error) {
      setState(() {
        _message =
            'Export impossible : ${error.toString().replaceFirst('Exception: ', '')}';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exporter les données')),
    body: SafeArea(
      child: FutureBuilder<List<NfcBatch>>(
        future: _batches,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return IziErrorState(
              message: 'Impossible de charger les dossiers. Vérifiez votre connexion.',
              onRetry:
                  () => setState(
                    () => _batches = widget.repository.listBatchStats(),
                  ),
            );
          }
          final batches = snapshot.data ?? const <NfcBatch>[];
          if (batches.isEmpty)
            return const IziEmptyState(
              icon: Icons.ios_share_rounded,
              title: 'Rien à exporter',
              message: 'Créez un dossier et ajoutez des cartes pour pouvoir exporter.',
            );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const Text(
                'Export CSV (séparateur « ; », ouverture directe dans Excel).',
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color:
                        _messageIsError
                            ? context.ink.error
                            : context.ink.verified,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...batches.map(
                (batch) => Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.inventory_2_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(batch.name),
                    subtitle: Text(
                      '${batch.total} carte(s) · ${batch.verified} vérifiée(s)',
                    ),
                    trailing:
                        _busyId == batch.id
                            ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.download_rounded),
                    onTap: _busyId == null ? () => _export(batch) : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
