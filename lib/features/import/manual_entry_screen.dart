import 'package:flutter/material.dart';

import '../../core/widgets/izi_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/card_format.dart';
import '../../data/models/import_result.dart';
import '../../data/models/nfc_batch.dart';
import '../../data/repositories/batch_repository.dart';
import 'import_result_screen.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    super.key,
    required this.contextData,
    required this.repository,
  });
  final BatchImportContext contextData;
  final BatchRepository repository;

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  String? _error;

  List<CardField> get _fields => widget.contextData.format.fields;

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _requiredAnyHelp() {
    final raw = widget.contextData.format.rules['required_any'];
    if (raw is! List) return const [];
    return raw.whereType<List>().map((group) {
      final labels =
          group.map((key) {
            final name = key.toString();
            final matches = _fields.where((field) => field.key == name);
            return matches.isEmpty ? name : matches.first.label;
          }).toList();
      return 'Au moins un de : ${labels.join(' / ')}';
    }).toList();
  }

  Future<void> _submit() async {
    if (_saving || _fields.isEmpty) return;
    final values = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) values[entry.key] = value;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await widget.repository.importRows(
        batchId: widget.contextData.id,
        rows: [values],
        filename: 'Saisie manuelle',
      );
      final inserted = _intValue(response['inserted']);
      final failed = _intValue(response['failed']);
      final rawErrors = response['errors'];
      final manualValues = <String, String>{
        for (final field in _fields)
          if ((values[field.key] ?? '').toString().isNotEmpty)
            field.label: values[field.key].toString(),
      };
      final failures = <ImportRowFailure>[];
      if (rawErrors is List) {
        for (final rawError in rawErrors) {
          if (rawError is Map) {
            failures.add(
              ImportRowFailure(
                sourceLine: 1,
                message:
                    rawError['message']?.toString() ??
                    'Ligne refusée.',
                sourceValues: manualValues,
              ),
            );
          }
        }
      }
      if (failed > failures.length) {
        failures.add(
          ImportRowFailure(
            sourceLine: 1,
            message: 'Ligne refusée.',
            sourceValues: manualValues,
          ),
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder:
              (_) => ImportResultScreen(
                result: ImportResult(
                  attempted: 1,
                  inserted: inserted,
                  failed: failed,
                  failures: failures,
                ),
                headers: _fields.map((field) => field.label).toList(),
              ),
        ),
      );
      if (mounted && inserted > 0) {
        for (final controller in _controllers.values) {
          controller.clear();
        }
        setState(() {});
      }
    } catch (error) {
      if (mounted)
        setState(
          () =>
              _error =
                  error is PostgrestException
                      ? error.message
                      : error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _intValue(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saisie manuelle')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                IziHero(
                  icon: Icons.edit_note_rounded,
                  title: widget.contextData.name,
                  subtitle:
                      'Une saisie correspond à une carte. Les contrôles finaux sont faits à l’enregistrement.',
                ),
                const IziSectionTitle('Informations de la carte'),
        if (_fields.isEmpty)
                  const IziNotice(
                    'Ce format ne contient aucun champ de saisie.',
                    tone: IziTone.warning,
                  )
                else ...[
                  ..._fields.map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: _controllers[field.key],
                        keyboardType: switch (field.type) {
                          'phone' => TextInputType.phone,
                          'email' => TextInputType.emailAddress,
                          'url' => TextInputType.url,
                          'lat' || 'lng' => const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          'code' =>
                            widget.contextData.settings['code_charset'] == 'alnum'
                                ? TextInputType.text
                                : TextInputType.number,
                          _ => TextInputType.text,
                        },
                        textCapitalization:
                            field.type == 'text'
                                ? TextCapitalization.sentences
                                : TextCapitalization.none,
                        maxLines: field.type == 'text' ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: '${field.label}${field.required ? ' *' : ''}',
                          helperText:
                              field.digitsOnly
                                  ? 'Saisir uniquement les chiffres.'
                                  : null,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  ..._requiredAnyHelp().map(
                    (help) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IziNotice(help),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  IziNotice(_error!, tone: IziTone.error),
                ],
              ],
            ),
          ),
          IziBottomBar(
            child: FilledButton.icon(
              onPressed:
                  _saving ||
                          _fields.isEmpty ||
                          widget.contextData.status == 'archived'
                      ? null
                      : _submit,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Enregistrement…' : 'Ajouter cette carte'),
            ),
          ),
        ],
      ),
    ),
  );
}
