import '../../data/models/card_format.dart';

class RowValidationIssue {
  const RowValidationIssue({required this.message});
  final String message;
}

class RowValidator {
  const RowValidator._();

  /// Bloque seulement les champs qui doivent être associés avant l'envoi.
  /// La validation des valeurs appartient à la RPC nfc_import_rows.
  static List<RowValidationIssue> validateMapping(
    CardFormat format,
    Map<int, String?> mapping,
  ) {
    final mapped = mapping.values.whereType<String>().toSet();
    final issues = <RowValidationIssue>[];
    for (final field in format.fields.where((field) => field.required)) {
      if (!mapped.contains(field.key)) {
        issues.add(RowValidationIssue(message: 'Associez une colonne au champ obligatoire « ${field.label} ».'));
      }
    }
    final groups = format.rules['required_any'];
    if (groups is List) {
      for (final group in groups.whereType<List>()) {
        final keys = group.map((key) => key.toString()).toList();
        if (keys.every((key) => !mapped.contains(key))) {
          final labels = keys.map((key) => format.fields.where((field) => field.key == key).isEmpty
              ? key
              : format.fields.firstWhere((field) => field.key == key).label).join(' / ');
          issues.add(RowValidationIssue(message: 'Associez au moins un de ces champs : $labels.'));
        }
      }
    }
    return issues;
  }
}
