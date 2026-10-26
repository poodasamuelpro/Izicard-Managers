import 'package:flutter/material.dart';
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
        _message = 'Export impossible : ${error.toString().replaceFirst('Exception: ', '')}';
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
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off_rounded, size: 44),
                    const SizedBox(height: 12),
                    const Text('Impossible de charger les dossiers.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _batches = widget.repository.listBatchStats()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                    ),
                  ]),
                );
              }
              final batches = snapshot.data ?? const <NfcBatch>[];
              if (batches.isEmpty) return const Center(child: Text('Aucun dossier à exporter.'));
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  const Text('Export CSV (séparateur « ; », ouverture directe dans Excel).'),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!,
                        style: TextStyle(
                            color: _messageIsError ? IzicardColors.statusError : IzicardColors.statusVerified,
                            fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 12),
                  ...batches.map((batch) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined, color: IzicardColors.cyan),
                          title: Text(batch.name),
                          subtitle: Text('${batch.total} carte(s) · ${batch.verified} vérifiée(s)'),
                          trailing: _busyId == batch.id
                              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download_rounded),
                          onTap: _busyId == null ? () => _export(batch) : null,
                        ),
                      )),
                ],
              );
            },
          ),
        ),
      );
}
