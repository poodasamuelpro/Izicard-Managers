import 'package:flutter/material.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/card_format.dart';
import '../../services/import/column_matcher.dart';
import '../../services/import/excel_reader.dart';
import '../../services/import/row_validator.dart';

class ColumnMappingStep extends StatelessWidget {
  const ColumnMappingStep({
    super.key,
    required this.sheet,
    required this.format,
    required this.mapping,
    required this.onChanged,
    required this.onContinue,
    required this.onTemplate,
  });

  final ImportSheet sheet;
  final CardFormat format;
  final Map<int, String?> mapping;
  final ValueChanged<Map<int, String?>> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    final missing = RowValidator.validateMapping(format, mapping);
    final options = ColumnMatcher.destinations(format);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Associez chaque colonne de votre fichier au champ correspondant de ${format.label}.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text('${sheet.rows.length} lignes · ${sheet.headers.length} colonnes', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        ...List.generate(sheet.headers.length, (index) {
          final selected = mapping[index];
          final usedElsewhere = mapping.entries.where((entry) => entry.key != index && entry.value != null).map((entry) => entry.value).toSet();
          final choices = options.where((key) => key == selected || !usedElsewhere.contains(key)).toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sheet.headers[index].trim().isEmpty ? 'Colonne ${index + 1}' : sheet.headers[index], style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: selected,
                  decoration: const InputDecoration(isDense: true, labelText: 'Champ du format', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Ignorer cette colonne')),
                    ...choices.map((key) {
                      final matchingFields = format.fields.where((candidate) => candidate.key == key);
                      final field = matchingFields.isEmpty ? null : matchingFields.first;
                      final label = field == null ? key : '${field.label}${field.required ? ' · obligatoire' : ''}';
                      return DropdownMenuItem<String?>(value: key, child: Text(label, overflow: TextOverflow.ellipsis));
                    }),
                  ],
                  onChanged: (value) {
                    final next = Map<int, String?>.from(mapping)..[index] = value;
                    onChanged(next);
                  },
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 10),
        if (missing.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)),
            child: Text(missing.map((issue) => issue.message).join('\n')),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.1), borderRadius: BorderRadius.circular(14)),
            child: const Text('Les règles de validation finales sont celles du schéma nfc. Les lignes invalides seront signalées sans empêcher les autres d’être importées.'),
          ),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: onTemplate, icon: const Icon(Icons.download_outlined), label: const Text('Télécharger le modèle de ce format')),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: missing.isEmpty ? onContinue : null, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Vérifier l’aperçu')),
      ],
    );
  }
}
