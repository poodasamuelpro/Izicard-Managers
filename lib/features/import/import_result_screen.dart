import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/izicard_colors.dart';
import '../../core/widgets/izi_ui.dart';
import '../../data/models/import_result.dart';

class ImportResultScreen extends StatelessWidget {
  const ImportResultScreen({
    super.key,
    required this.result,
    required this.headers,
  });
  final ImportResult result;
  final List<String> headers;

  String _csv() {
    final columns = [...headers, 'erreur_serveur'];
    String quote(String value) => '"${value.replaceAll('"', '""')}"';
    final rows = <String>[
      columns.map(quote).join(';'),
      ...result.failures.map(
        (failure) => [
          ...headers.map((header) => failure.sourceValues[header] ?? ''),
          failure.message,
        ].map(quote).join(';'),
      ),
    ];
    return '\uFEFF${rows.join('\r\n')}';
  }

  Future<void> _shareErrors(BuildContext context) async {
    try {
      final bytes = utf8.encode(_csv());
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'text/csv',
            name: 'izicard-erreurs-import.csv',
          ),
        ],
        subject: 'Erreurs de l’import IziCard',
        text: 'Lignes rejetées par la validation.',
      );
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de préparer le fichier CSV.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Résultat de l’import')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                IziHero(
                  icon:
                      result.failed == 0
                          ? Icons.check_circle_outline_rounded
                          : Icons.rule_rounded,
                  title: '${result.inserted} carte(s) importée(s)',
                  subtitle:
                      result.failed == 0
                          ? 'Toutes les lignes ont été importées.'
                          : '${result.failed} ligne(s) rejetée(s) sur ${result.attempted}.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: IziStat(
                        value: '${result.attempted}',
                        label: 'Lignes traitées',
                        icon: Icons.table_rows_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: IziStat(
                        value: '${result.inserted}',
                        label: 'Importées',
                        icon: Icons.check_rounded,
                        color: context.ink.verified,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: IziStat(
                        value: '${result.failed}',
                        label: 'En erreur',
                        icon: Icons.error_outline_rounded,
                        color: result.failed > 0 ? context.ink.error : null,
                      ),
                    ),
                  ],
                ),
                if (result.failures.isNotEmpty) ...[
                  const IziSectionTitle('Lignes rejetées'),
                  ...result.failures.map(
                    (failure) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${failure.sourceLine}'),
                        ),
                        title: Text(failure.message),
                        subtitle: Text(
                          failure.sourceValues.entries
                              .map((entry) => '${entry.key}: ${entry.value}')
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IziBottomBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (result.failures.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () => _shareErrors(context),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Exporter les erreurs en CSV'),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Retour au dossier'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
