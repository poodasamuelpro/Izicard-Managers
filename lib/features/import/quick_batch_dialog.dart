import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/izi_ui.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/card_format.dart';
import '../../data/models/nfc_client.dart';
import '../../data/repositories/client_repository.dart';
import '../admin/clients/client_form_screen.dart';
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
  static const _internal = 'internal';
  List<NfcClient> _clients = const [];
  String _destination = _internal;
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
    if (widget.profile.role == NfcRole.admin) unawaited(_loadClients());
  }

  Future<void> _loadClients() async {
    try {
      final all =
          await ClientRepository(Supabase.instance.client).listClients();
      if (!mounted) return;
      setState(
        () =>
            _clients =
                all.where((c) => !c.name.contains('usage interne')).toList(),
      );
    } catch (_) {
      // Liste indisponible : « pour moi » reste possible.
    }
  }

  Future<void> _newClient() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => ClientFormScreen(
              repository: ClientRepository(Supabase.instance.client),
              onCreated: (id) => _destination = id,
            ),
      ),
    );
    if (created == true) await _loadClients();
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
              ? (_destination == _internal
                  ? await widget.repository.ensureInternalClient()
                  : _destination)
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
              if (widget.profile.role == NfcRole.admin) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value:
                      _clients.any((c) => c.id == _destination) ||
                              _destination == _internal
                          ? _destination
                          : _internal,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Dossier pour',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _internal,
                      child: Text('Moi-même (usage interne IziCard)'),
                    ),
                    ..._clients.map(
                      (client) => DropdownMenuItem(
                        value: client.id,
                        child: Text(client.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged:
                      _saving
                          ? null
                          : (value) =>
                              setState(() => _destination = value ?? _internal),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _newClient,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Nouveau client'),
                  ),
                ),
              ],
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
                IziNotice(_error!, tone: IziTone.error),
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
