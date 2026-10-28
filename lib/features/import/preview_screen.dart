import 'package:flutter/material.dart';

import '../../core/widgets/izi_ui.dart';
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
        IziHero(
          icon: Icons.fact_check_outlined,
          title: '${sheet.rows.length} lignes prêtes',
          subtitle:
              'Aperçu des cinq premières lignes. Le contrôle définitif est fait à l’envoi.',
        ),
        const SizedBox(height: 8),
        if (activeColumns.isEmpty)
          const IziNotice(
            'Aucune colonne n’est associée.',
            tone: IziTone.warning,
          )
        else
          for (final entry in activeColumns) ...[
            IziSectionTitle(
              format.fields.where((field) => field.key == entry.value).isEmpty
                  ? entry.value!
                  : format.fields
                      .firstWhere((field) => field.key == entry.value)
                      .label,
              padding: const EdgeInsets.only(top: 16, bottom: 6),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      sheet.rows
                          .take(5)
                          .map(
                            (row) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Ligne ${row.sourceLine} · ${entry.key < row.values.length ? row.values[entry.key] : ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
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
