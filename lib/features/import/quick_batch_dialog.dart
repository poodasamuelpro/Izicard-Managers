import 'package:flutter/material.dart';

import '../../data/models/card_format.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/batch_repository.dart';

/// Création rapide d'un dossier pour un import : nom + format, sans passer par un client ni
/// par la page « Créer un dossier ». Admin : rattaché au client interne ; client : à son compte.
/// Retourne l'identifiant du dossier créé.
class QuickBatchDialog extends StatefulWidget {
  const QuickBatchDialog({
    super.key,
    required this.profile,
    required this.repository,
  });

  final NfcProfile profile;
  final BatchRepository repository;

  @override
  State<QuickBatchDialog> createState() => _QuickBatchDialogState();
}

class _QuickBatchDialogState extends State<QuickBatchDialog> {
  final _name = TextEditingController();
  late Future<List<CardFormat>> _formats;
  CardFormat? _format;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    _name.text =
        'Import du ${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';
    _formats = widget.repository.listActiveFormats();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final format = _format;
    if (format == null || _saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Donnez un nom au dossier.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final clientId =
          widget.profile.role == NfcRole.admin
              ? await widget.repository.ensureInternalClient()
              : widget.profile.clientId;
      if (clientId == null) throw Exception('Aucun client lié à ce compte.');
      final id = await widget.repository.createBatch(
        clientId: clientId,
        formatId: format.id,
        name: _name.text,
        quantity: 0,
        dataType: format.defaultDataType,
        lockAfterWrite: format.lockDefault,
      );
      if (mounted) Navigator.of(context).pop(id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouveau dossier'),
    content: SingleChildScrollView(
      child: FutureBuilder<List<CardFormat>>(
        future: _formats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final formats = snapshot.data ?? const <CardFormat>[];
          if (snapshot.hasError || formats.isEmpty) {
            return const Text('Impossible de charger les formats de carte.');
          }
          _format ??= formats.first;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Nom du dossier'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _format!.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Format de carte'),
                items:
                    formats
                        .map(
                          (format) => DropdownMenuItem(
                            value: format.id,
                            child: Text(
                              '${format.label} · ${format.chip}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged:
                    _saving
                        ? null
                        : (value) => setState(
                          () =>
                              _format =
                                  formats.firstWhere((f) => f.id == value),
                        ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _saving ? null : _create,
        child: Text(_saving ? 'Création…' : 'Créer'),
      ),
    ],
  );
}
