import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_tag.dart';

/// Export CSV d'un dossier : séparateur « ; », UTF-8 avec BOM (ouverture directe dans Excel).
class CsvExporter {
  const CsvExporter._();

  static String _cell(Object? value) {
    var text = value == null ? '' : value.toString();
    // Protection contre l'injection de formules dans Excel.
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(text)) text = "'$text";
    if (text.contains(';') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String build(List<NfcTagRecord> tags) {
    final keys = <String>{for (final tag in tags) ...tag.fields.keys}.toList()..sort();
    final header = [
      'seq',
      'public_id',
      'statut',
      'type',
      'donnée',
      ...keys,
      'uid',
      'tentatives',
      'dernière erreur',
      'date d’écriture',
    ];
    final lines = <String>[header.map(_cell).join(';')];
    for (final tag in tags) {
      lines.add([
        tag.sequence,
        tag.publicId,
        IzicardColors.labelForTagStatus(tag.status),
        tag.dataType,
        tag.payload,
        ...keys.map((key) => tag.fields[key]),
        tag.uid,
        tag.attempts,
        tag.lastError,
        tag.writtenAt,
      ].map(_cell).join(';'));
    }
    return lines.join('\r\n') + '\r\n';
  }

  static String fileName(String batchName) {
    final safe = batchName.replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ_-]+'), '_');
    final trimmed = safe.length > 50 ? safe.substring(0, 50) : safe;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return '${trimmed.isEmpty ? 'dossier' : trimmed}_$day.csv';
  }

  /// Écrit le fichier dans le dossier temporaire puis ouvre le partage Android.
  static Future<int> share({required String batchName, required List<NfcTagRecord> tags}) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${fileName(batchName)}');
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(build(tags))], flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], subject: 'Export $batchName');
    return tags.length;
  }
}
