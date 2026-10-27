import 'package:flutter/material.dart';

import '../../data/models/card_format.dart';
import '../../services/import/excel_reader.dart';

class ImportPreviewStep extends StatelessWidget {
  const ImportPreviewStep({
    super.key,
    required this.sheet,
    required this.format,
    required this.mapping,
    required this.onBack,
    required this.onImport,
    required this.isImporting,
  });

  final ImportSheet sheet;
  final CardFormat format;
  final Map<int, String?> mapping;
  final VoidCallback onBack;
  final VoidCallback onImport;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    final activeColumns =
        mapping.entries.where((entry) => entry.value != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${sheet.rows.length} lignes prêtes à vérifier',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Aperçu des cinq premières lignes. Le contrôle définitif est fait à l’envoi.',
        ),
        const SizedBox(height: 12),
        if (activeColumns.isEmpty)
          const Text('Aucune colonne n’est associée.')
        else
          for (final entry in activeColumns) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 5),
              child: Text(
                format.fields.where((field) => field.key == entry.value).isEmpty
                    ? entry.value!
                    : format.fields
                        .firstWhere((field) => field.key == entry.value)
                        .label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ...sheet.rows
                .take(5)
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      'Ligne ${row.sourceLine} · ${entry.key < row.values.length ? row.values[entry.key] : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: isImporting ? null : onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Modifier les correspondances'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: isImporting || sheet.rows.isEmpty ? null : onImport,
          icon:
              isImporting
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.cloud_upload_outlined),
          label: Text(
            isImporting
                ? 'Import en cours…'
                : 'Importer ${sheet.rows.length} lignes',
          ),
        ),
      ],
    );
  }
}
