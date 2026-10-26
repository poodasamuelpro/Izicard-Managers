import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/import_result.dart';

class ImportResultScreen extends StatelessWidget {
  const ImportResultScreen({super.key, required this.result, required this.headers});
  final ImportResult result;
  final List<String> headers;

  String _csv() {
    final columns = [...headers, 'erreur_serveur'];
    String quote(String value) => '"${value.replaceAll('"', '""')}"';
    final rows = <String>[
      columns.map(quote).join(';'),
      ...result.failures.map((failure) => [
        ...headers.map((header) => failure.sourceValues[header] ?? ''),
        failure.message,
      ].map(quote).join(';')),
    ];
    return '\uFEFF${rows.join('\r\n')}';
  }

  Future<void> _shareErrors(BuildContext context) async {
    try {
      final bytes = utf8.encode(_csv());
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'text/csv', name: 'izicard-erreurs-import.csv')],
        subject: 'Erreurs de l’import IziCard',
        text: 'Lignes rejetées par la validation Supabase.',
      );
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de préparer le fichier CSV.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Résultat de l’import')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
            _Metric(label: 'Lignes traitées', value: result.attempted),
            _Metric(label: 'Cartes importées', value: result.inserted),
            _Metric(label: 'Lignes en erreur', value: result.failed, error: result.failed > 0),
          ]))),
          const SizedBox(height: 18),
          if (result.failures.isNotEmpty) ...[
            FilledButton.tonalIcon(onPressed: () => _shareErrors(context), icon: const Icon(Icons.ios_share_rounded), label: const Text('Exporter les erreurs en CSV')),
            const SizedBox(height: 14),
            Text('Lignes rejetées par Supabase', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result.failures.map((failure) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${failure.sourceLine}')),
                title: Text(failure.message),
                subtitle: Text(failure.sourceValues.entries.map((entry) => '${entry.key}: ${entry.value}').join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            )),
          ] else
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('Toutes les lignes ont été importées.', textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Retour au dossier')),
        ]),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.error = false});
  final String label; final int value; final bool error;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
    Expanded(child: Text(label)), Text('$value', style: TextStyle(fontWeight: FontWeight.w800, color: error ? Theme.of(context).colorScheme.error : null)),
  ]));
}
