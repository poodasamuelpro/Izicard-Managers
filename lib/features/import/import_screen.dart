import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/card_format.dart';
import '../../data/models/import_result.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/batch_repository.dart';
import '../../services/import/column_matcher.dart';
import '../../services/import/excel_reader.dart';
import '../../services/import/row_validator.dart';
import 'import_result_screen.dart';
import 'manual_entry_screen.dart';
import 'mapping_screen.dart';
import 'preview_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    required this.profile,
    required this.repository,
    this.initialBatchId,
  });
  final NfcProfile profile;
  final BatchRepository repository;
  final String? initialBatchId;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late Future<List<NfcBatch>> _batchesFuture;
  Future<BatchImportContext>? _contextFuture;
  String? _batchId;
  String? _filename;
  String? _extension;
  List<ImportSheet> _sheets = const [];
  ImportSheet? _sheet;
  Map<int, String?> _mapping = const {};
  int _step = 0;
  bool _busy = false;
  int _sentRows = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _batchesFuture = widget.repository.listBatchStats();
  }

  Future<void> _refreshBatches() async {
    final future = widget.repository.listBatchStats();
    setState(() => _batchesFuture = future);
    try {
      await future;
    } catch (_) {}
  }

  void _selectBatch(String id) {
    if (id == _batchId) return;
    setState(() {
      _batchId = id;
      _contextFuture = widget.repository.getImportContext(id);
      _filename = null;
      _extension = null;
      _sheets = const [];
      _sheet = null;
      _mapping = const {};
      _step = 0;
      _error = null;
    });
  }

  Future<void> _pickFile(CardFormat format) async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size > ExcelReader.maxFileBytes) {
        throw const FormatException(
          'Le fichier dépasse la limite mobile de 20 Mo.',
        );
      }
      final extension = (file.extension ?? '').toLowerCase();
      if (!const {'xlsx', 'xls', 'csv'}.contains(extension)) {
        throw const FormatException(
          'Sélectionnez un fichier .xlsx, .xls ou .csv.',
        );
      }
      final Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw const FormatException(
          'Impossible de lire le fichier sélectionné.',
        );
      }
      final sheets = await ExcelReader.readBytes(bytes, extension);
      if (sheets.isEmpty)
        throw const FormatException(
          'Aucune feuille contenant des colonnes n’a été trouvée.',
        );
      if (!mounted) return;
      setState(() {
        _filename = file.name;
        _extension = extension;
        _sheets = sheets;
        _sheet = sheets.first;
        _mapping = ColumnMatcher.suggest(sheets.first.headers, format);
        _step = 1;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException) return error.message;
    final message = error
        .toString()
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Exception: ', '');
    return message.length > 260
        ? 'Impossible de lire ce fichier. Vérifiez son format et réessayez.'
        : message;
  }

  void _selectSheet(ImportSheet sheet, CardFormat format) {
    setState(() {
      _sheet = sheet;
      _mapping = ColumnMatcher.suggest(sheet.headers, format);
      _step = 1;
    });
  }

  Map<String, dynamic> _mappingForServer(ImportSheet sheet) {
    final mapping = <String, dynamic>{};
    for (final entry in _mapping.entries) {
      final target = entry.value;
      if (target == null || entry.key >= sheet.headers.length) continue;
      final header = sheet.headers[entry.key].trim();
      mapping[header] = target;
    }
    return mapping;
  }

  List<_PreparedImportRow> _prepareRows(ImportSheet sheet) {
    final prepared = <_PreparedImportRow>[];
    for (final source in sheet.rows) {
      final values = <String, dynamic>{};
      for (final entry in _mapping.entries) {
        final target = entry.value;
        if (target == null || entry.key >= source.values.length) continue;
        final value = source.values[entry.key].trim();
        if (value.isNotEmpty) values[target] = value;
      }
      if (values.isNotEmpty) {
        prepared.add(
          _PreparedImportRow(
            sourceLine: source.sourceLine,
            values: values,
            sourceValues: {
              for (var index = 0; index < sheet.headers.length; index++)
                sheet.headers[index]:
                    index < source.values.length ? source.values[index] : '',
            },
          ),
        );
      }
    }
    return prepared;
  }

  Future<void> _submitImport() async {
    final sheet = _sheet;
    final batchId = _batchId;
    if (_busy || sheet == null || batchId == null) return;
    final rows = _prepareRows(sheet);
    if (rows.isEmpty) {
      setState(
        () =>
            _error =
                'Aucune donnée n’est associée aux champs du format. Revenez au mapping.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _sentRows = 0;
      _error = null;
    });
    var aggregate = ImportResult.empty;
    const chunkSize = 500;
    var stop = false;
    for (var start = 0; start < rows.length; start += chunkSize) {
      final chunk = rows.skip(start).take(chunkSize).toList();
      setState(() => _sentRows = start);
      try {
        final response = await widget.repository.importRows(
          batchId: batchId,
          rows: chunk.map((row) => row.values).toList(),
          filename: _filename,
          mapping: _mappingForServer(sheet),
        );
        final inserted = _asInt(response['inserted']);
        final failed = _asInt(response['failed']);
        final rawErrors = response['errors'];
        final errorRows = rawErrors is List ? rawErrors : const [];
        final failures = <ImportRowFailure>[];
        final seen = <int>{};
        for (final rawError in errorRows) {
          if (rawError is! Map) continue;
          final localRow = _asInt(rawError['row']);
          if (localRow < 1 || localRow > chunk.length) continue;
          final prepared = chunk[localRow - 1];
          failures.add(
            ImportRowFailure(
              sourceLine: prepared.sourceLine,
              message:
                  rawError['message']?.toString() ??
                  'Ligne refusée par Supabase.',
              sourceValues: prepared.sourceValues,
            ),
          );
          seen.add(localRow);
        }
        // La RPC conserve au plus 200 messages détaillés par appel. Garde tout de même
        // une ligne exportable pour chaque rejet et signale l’absence de détail.
        if (failed > failures.length) {
          for (
            var index = 0;
            index < chunk.length && failures.length < failed;
            index++
          ) {
            if (seen.contains(index + 1)) continue;
            final prepared = chunk[index];
            failures.add(
              ImportRowFailure(
                sourceLine: prepared.sourceLine,
                message:
                    'Ligne rejetée par Supabase; détail non retourné par la RPC.',
                sourceValues: prepared.sourceValues,
              ),
            );
          }
        }
        aggregate =
            aggregate +
            ImportResult(
              attempted: chunk.length,
              inserted: inserted,
              failed: failed,
              failures: failures,
            );
        setState(() => _sentRows = start + chunk.length);
      } catch (error) {
        final message = _friendlyError(error);
        final failedRows = rows.skip(start).toList();
        aggregate =
            aggregate +
            ImportResult(
              attempted: failedRows.length,
              inserted: 0,
              failed: failedRows.length,
              failures:
                  failedRows
                      .map(
                        (row) => ImportRowFailure(
                          sourceLine: row.sourceLine,
                          message: 'Envoi interrompu : $message',
                          sourceValues: row.sourceValues,
                        ),
                      )
                      .toList(),
            );
        stop = true;
        break;
      }
    }
    if (!mounted) return;
    if (stop && _sentRows > 0) {
      setState(
        () =>
            _error =
                'L’envoi s’est interrompu. Les premiers lots ont pu être enregistrés; consultez le bilan avant de relancer.',
      );
    }
    setState(() => _busy = false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                ImportResultScreen(result: aggregate, headers: sheet.headers),
      ),
    );
    if (mounted) {
      setState(() {
        _filename = null;
        _extension = null;
        _sheets = const [];
        _sheet = null;
        _mapping = const {};
        _step = 0;
        _error = null;
      });
    }
  }

  int _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _downloadTemplate(CardFormat format) async {
    try {
      final workbook = xlsx.Excel.createExcel();
      final sheet = workbook['Sheet1'];
      for (var column = 0; column < format.fields.length; column++) {
        final field = format.fields[column];
        final headerCell = sheet.cell(
          xlsx.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
        );
        headerCell.value = xlsx.TextCellValue(field.label);
        if (field.type == 'code' || field.type == 'phone') {
          final textStyle = xlsx.CellStyle(
            numberFormat: xlsx.CustomNumericNumFormat(formatCode: '@'),
          );
          for (var row = 1; row <= 1000; row++) {
            final valueCell = sheet.cell(
              xlsx.CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: row,
              ),
            );
            valueCell.value = xlsx.TextCellValue('');
            valueCell.cellStyle = textStyle;
          }
        } else {
          sheet
              .cell(
                xlsx.CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: 1,
                ),
              )
              .value = xlsx.TextCellValue('');
        }
      }
      final instructions = workbook['Instructions'];
      final rows = <List<String>>[
        ['Instructions', ''],
        ['Format', format.label],
        ['Type de donnée', format.defaultDataType],
        ['Puce', '${format.chip} · ${format.capacityBytes} octets'],
        [
          'Lecture',
          'Ligne 1 = en-têtes. Ne modifiez pas les clés/colonnes du modèle.',
        ],
        [
          'Validation',
          'La validation et le nettoyage sont effectués par Supabase nfc_import_rows.',
        ],
        ['Champs', 'Champ | Type | Obligatoire | Exemple | Alias'],
        ...format.fields.map(
          (field) => [
            field.label,
            field.type,
            field.required ? 'Oui' : 'Non',
            _exampleFor(field),
            field.aliases.join(', '),
          ],
        ),
      ];
      final requiredAny = format.rules['required_any'];
      if (requiredAny is List) {
        for (final group in requiredAny.whereType<List>()) {
          final labels = group
              .map((key) {
                final matches = format.fields.where(
                  (field) => field.key == key.toString(),
                );
                return matches.isEmpty ? key.toString() : matches.first.label;
              })
              .join(' / ');
          rows.add(['Règle required_any', 'Au moins un de : $labels']);
        }
      }
      for (var row = 0; row < rows.length; row++) {
        for (var column = 0; column < rows[row].length; column++) {
          instructions
              .cell(
                xlsx.CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: row,
                ),
              )
              .value = xlsx.TextCellValue(rows[row][column]);
        }
      }
      final bytes = workbook.encode();
      if (bytes == null)
        throw const FormatException('Le modèle Excel n’a pas pu être créé.');
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: 'modele-${format.code}.xlsx',
          ),
        ],
        subject: 'Modèle d’import ${format.label}',
        text:
            'Les en-têtes suivent les champs du format nfc. Les alias reconnus sont disponibles dans l’application.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  String _exampleFor(CardField field) => switch (field.type) {
    'url' => 'https://exemple.fr',
    'phone' => '+33123456789',
    'email' => 'nom@exemple.fr',
    'code' => '007123',
    'lat' => '48.8566',
    'lng' => '2.3522',
    _ => 'Exemple de ${field.label.toLowerCase()}',
  };

  Future<void> _openManual(BatchImportContext contextData) async {
    if (contextData.status == 'archived') {
      setState(
        () => _error = 'Un dossier archivé ne peut plus recevoir d’import.',
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => ManualEntryScreen(
              contextData: contextData,
              repository: widget.repository,
            ),
      ),
    );
    if (mounted) await _refreshBatches();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Importer des données')),
    body: SafeArea(
      child: FutureBuilder<List<NfcBatch>>(
        future: _batchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _LoadError(onRetry: _refreshBatches);
          final batches =
              (snapshot.data ?? const <NfcBatch>[])
                  .where((batch) => batch.status != 'archived')
                  .toList();
          if (batches.isEmpty)
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Aucun dossier actif n’est disponible pour votre compte.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          if (_batchId == null ||
              !batches.any((batch) => batch.id == _batchId)) {
            final matchingInitial = batches.where(
              (batch) => batch.id == widget.initialBatchId,
            );
            final desired =
                matchingInitial.isEmpty ? null : matchingInitial.first;
            _batchId = desired?.id ?? batches.first.id;
            _contextFuture = widget.repository.getImportContext(_batchId!);
          }
          final selectedId = _batchId!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(
                  labelText: 'Dossier',
                  prefixIcon: Icon(Icons.folder_outlined),
                  border: OutlineInputBorder(),
                ),
                items:
                    batches
                        .map(
                          (batch) => DropdownMenuItem(
                            value: batch.id,
                            child: Text(
                              batch.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged:
                    _busy
                        ? null
                        : (value) {
                          if (value != null) _selectBatch(value);
                        },
              ),
              const SizedBox(height: 14),
              FutureBuilder<BatchImportContext>(
                key: ValueKey(selectedId),
                future: _contextFuture,
                builder: (context, contextSnapshot) {
                  if (contextSnapshot.connectionState != ConnectionState.done)
                    return const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  if (contextSnapshot.hasError)
                    return _LoadError(onRetry: () => _selectBatch(selectedId));
                  final contextData = contextSnapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Compte actif · ${widget.profile.role.label}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      _BatchSummary(contextData: contextData),
                      const SizedBox(height: 16),
                      if (contextData.status == 'archived')
                        const Text(
                          'Ce dossier est archivé; import et saisie sont désactivés.',
                        )
                      else ...[
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              icon: Icon(Icons.upload_file_outlined),
                              label: Text('Fichier'),
                            ),
                            ButtonSegment(
                              value: 3,
                              icon: Icon(Icons.edit_note_rounded),
                              label: Text('Saisie manuelle'),
                            ),
                          ],
                          selected: {_step == 3 ? 3 : 0},
                          onSelectionChanged:
                              _busy
                                  ? null
                                  : (selection) {
                                    final value = selection.first;
                                    if (value == 3) {
                                      _openManual(contextData);
                                    } else {
                                      setState(
                                        () => _step = _sheet == null ? 0 : 1,
                                      );
                                    }
                                  },
                        ),
                        const SizedBox(height: 16),
                        if (_step == 0)
                          _FileStep(
                            filename: _filename,
                            extension: _extension,
                            error: _error,
                            onPick: () => _pickFile(contextData.format),
                            onTemplate:
                                () => _downloadTemplate(contextData.format),
                          ),
                        if (_step == 1 && _sheet != null) ...[
                          if (_sheets.length > 1)
                            DropdownButtonFormField<ImportSheet>(
                              value: _sheet,
                              decoration: const InputDecoration(
                                labelText: 'Feuille Excel',
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  _sheets
                                      .map(
                                        (sheet) => DropdownMenuItem(
                                          value: sheet,
                                          child: Text(sheet.name),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (sheet) {
                                if (sheet != null)
                                  _selectSheet(sheet, contextData.format);
                              },
                            ),
                          if (_sheets.length > 1) const SizedBox(height: 12),
                          if (_filename != null)
                            Text(
                              'Fichier : $_filename',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 10),
                          ColumnMappingStep(
                            sheet: _sheet!,
                            format: contextData.format,
                            mapping: _mapping,
                            onChanged:
                                (next) => setState(() => _mapping = next),
                            onContinue:
                                () => setState(() {
                                  _step = 2;
                                  _error = null;
                                }),
                            onTemplate:
                                () => _downloadTemplate(contextData.format),
                          ),
                        ],
                        if (_step == 2 && _sheet != null) ...[
                          if (_busy) ...[
                            Text(
                              '$_sentRows / ${_sheet!.rows.length} lignes envoyées',
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value:
                                  _sheet!.rows.isEmpty
                                      ? null
                                      : _sentRows / _sheet!.rows.length,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          ImportPreviewStep(
                            sheet: _sheet!,
                            format: contextData.format,
                            mapping: _mapping,
                            onBack: () => setState(() => _step = 1),
                            onImport: _submitImport,
                            isImporting: _busy,
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _PreparedImportRow {
  const _PreparedImportRow({
    required this.sourceLine,
    required this.values,
    required this.sourceValues,
  });
  final int sourceLine;
  final Map<String, dynamic> values;
  final Map<String, String> sourceValues;
}

class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.contextData});
  final BatchImportContext contextData;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withOpacity(.45),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contextData.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${contextData.format.label} · ${contextData.dataType.toUpperCase()} · ${contextData.format.chip} · ${contextData.format.capacityBytes} octets',
        ),
        const SizedBox(height: 5),
        const Text(
          'Fichier lu sur cet appareil; seules les lignes mappées sont envoyées à la RPC nfc_import_rows.',
        ),
      ],
    ),
  );
}

class _FileStep extends StatelessWidget {
  const _FileStep({
    required this.filename,
    required this.extension,
    required this.error,
    required this.onPick,
    required this.onTemplate,
  });
  final String? filename;
  final String? extension;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback onTemplate;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choisissez un fichier .xlsx, .xls ou .csv. Le fichier est lu localement; l’application affiche un aperçu avant tout envoi.',
      ),
      const SizedBox(height: 18),
      if (filename != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              filename!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(extension?.toUpperCase() ?? ''),
            trailing: IconButton(
              tooltip: 'Choisir un autre fichier',
              onPressed: onPick,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ),
      FilledButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.folder_open_rounded),
        label: Text(
          filename == null ? 'Choisir un fichier' : 'Remplacer le fichier',
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: onTemplate,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Télécharger un modèle vierge'),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42),
          const SizedBox(height: 10),
          const Text('Impossible de charger les dossiers.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}
