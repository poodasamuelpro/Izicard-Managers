import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:excel2003/excel2003.dart';
import 'package:flutter/foundation.dart';

class ImportSheet {
  const ImportSheet({
    required this.name,
    required this.headers,
    required this.rows,
  });

  final String name;
  final List<String> headers;
  final List<ImportSourceRow> rows;
}

class ImportSourceRow {
  const ImportSourceRow({required this.sourceLine, required this.values});
  final int sourceLine;
  final List<String> values;
}

class ExcelReader {
  const ExcelReader._();

  static const int maxFileBytes = 20 * 1024 * 1024;

  static Future<List<ImportSheet>> readBytes(
    Uint8List bytes,
    String extension,
  ) async {
    if (bytes.isEmpty) throw const FormatException('Le fichier est vide.');
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Le fichier dépasse la limite mobile de 20 Mo.');
    }
    final payload = await compute(_parseWorkbook, <String, Object>{
      'bytes': bytes,
      'extension': extension.toLowerCase().replaceFirst('.', ''),
    });
    return payload.map((sheet) {
      final map = Map<String, dynamic>.from(sheet);
      return ImportSheet(
        name: map['name'].toString(),
        headers: (map['headers'] as List).map((value) => value.toString()).toList(),
        rows: (map['rows'] as List).map((row) {
          final data = Map<String, dynamic>.from(row as Map);
          return ImportSourceRow(
            sourceLine: data['line'] as int,
            values: (data['values'] as List).map((value) => value.toString()).toList(),
          );
        }).toList(),
      );
    }).where((sheet) => sheet.headers.any((header) => header.trim().isNotEmpty)).toList();
  }
}

List<Map<String, dynamic>> _parseWorkbook(Map<String, Object> input) {
  final bytes = Uint8List.fromList(input['bytes'] as Uint8List);
  final extension = input['extension'] as String;
  if (extension == 'csv') return _parseCsv(bytes);
  if (extension == 'xlsx') return _parseXlsx(bytes);
  if (extension == 'xls') return _parseXls(bytes);
  throw const FormatException('Format non pris en charge. Utilisez .xlsx, .xls ou .csv.');
}

List<Map<String, dynamic>> _parseCsv(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
  if (text.isEmpty) throw const FormatException('Le CSV ne contient aucune donnée.');
  final delimiter = _detectDelimiter(text);
  final records = _decodeCsv(text, delimiter);
  return [_toSheet('CSV', records)];
}

String _detectDelimiter(String text) {
  final first = text.split(RegExp(r'\r?\n')).take(5).join('\n');
  final candidates = [',', ';', '\t'];
  var winner = ',';
  var best = -1;
  for (final candidate in candidates) {
    var count = 0;
    var quoted = false;
    for (var i = 0; i < first.length; i++) {
      final char = first[i];
      if (char == '"') {
        if (quoted && i + 1 < first.length && first[i + 1] == '"') {
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == candidate) {
        count++;
      }
    }
    if (count > best) {
      best = count;
      winner = candidate;
    }
  }
  return winner;
}

List<List<String>> _decodeCsv(String text, String delimiter) {
  final records = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && char == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      records.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    records.add(row);
  }
  if (quoted) throw const FormatException('Le CSV contient un guillemet non fermé.');
  return records;
}

List<Map<String, dynamic>> _parseXlsx(Uint8List bytes) {
  final workbook = xlsx.Excel.decodeBytes(bytes);
  final result = <Map<String, dynamic>>[];
  for (final entry in workbook.tables.entries) {
    final sheet = entry.value;
    if (sheet == null) continue;
    final matrix = sheet.rows.map((row) => row.map(_xlsxCellText).toList()).toList();
    final parsed = _toSheet(entry.key, matrix);
    if ((parsed['headers'] as List).any((value) => value.toString().trim().isNotEmpty)) {
      result.add(parsed);
    }
  }
  if (result.isEmpty) throw const FormatException('Aucune feuille avec des en-têtes n’a été trouvée.');
  return result;
}

String _xlsxCellText(xlsx.Data? cell) {
  final value = cell?.value;
  final formatCode = cell?.cellStyle?.numberFormat.formatCode.split(';').first.trim();
  if (value is xlsx.IntCellValue && formatCode != null && RegExp(r'^0+$').hasMatch(formatCode)) {
    return value.value.toString().padLeft(formatCode.length, '0');
  }
  if (value is xlsx.DoubleCellValue && formatCode != null && RegExp(r'^0+$').hasMatch(formatCode) && value.value == value.value.roundToDouble()) {
    return value.value.toInt().toString().padLeft(formatCode.length, '0');
  }
  return switch (value) {
      null => '',
      xlsx.TextCellValue(:final value) => value.toString(),
      xlsx.FormulaCellValue(:final formula) => formula,
      xlsx.IntCellValue(:final value) => value.toString(),
      xlsx.DoubleCellValue(:final value) => value.toString(),
      xlsx.BoolCellValue(:final value) => value ? 'true' : 'false',
      xlsx.DateCellValue() => value.asDateTimeLocal().toIso8601String().split('T').first,
      xlsx.DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
      xlsx.TimeCellValue() => value.asDuration().toString(),
    };
}

List<Map<String, dynamic>> _parseXls(Uint8List bytes) {
  final reader = XlsReader.fromBytes(bytes);
  final result = <Map<String, dynamic>>[];
  for (var index = 0; index < reader.sheetCount; index++) {
    final sheet = reader.sheet(index);
    final matrix = <List<String>>[];
    for (var row = 0; row < sheet.rowCount; row++) {
      matrix.add(List<String>.generate(sheet.colCount, (column) {
        final dynamic cell = sheet.cell(row, column);
        if (cell == null) return '';
        try {
          final dynamic value = cell.value;
          return value?.toString() ?? '';
        } catch (_) {
          return cell.toString();
        }
      }));
    }
    final parsed = _toSheet(sheet.name, matrix);
    if ((parsed['headers'] as List).any((value) => value.toString().trim().isNotEmpty)) {
      result.add(parsed);
    }
  }
  if (result.isEmpty) throw const FormatException('Aucune feuille avec des en-têtes n’a été trouvée.');
  return result;
}

Map<String, dynamic> _toSheet(String name, List<List<String>> matrix) {
  if (matrix.isEmpty) return {'name': name, 'headers': <String>[], 'rows': <Map<String, dynamic>>[]};
  final headers = _trimTrailingEmpty(matrix.first);
  if (headers.isEmpty) return {'name': name, 'headers': <String>[], 'rows': <Map<String, dynamic>>[]};
  final rows = <Map<String, dynamic>>[];
  for (var index = 1; index < matrix.length; index++) {
    final values = _trimTrailingEmpty(matrix[index]);
    if (values.every((value) => value.trim().isEmpty)) continue;
    while (values.length < headers.length) { values.add(''); }
    rows.add({'line': index + 1, 'values': values.take(headers.length).toList()});
  }
  return {'name': name, 'headers': headers, 'rows': rows};
}

List<String> _trimTrailingEmpty(List<String> source) {
  final values = List<String>.from(source);
  while (values.isNotEmpty && values.last.trim().isEmpty) { values.removeLast(); }
  return values;
}
