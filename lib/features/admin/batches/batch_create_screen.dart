import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/izicard_colors.dart';
import '../../../data/models/card_format.dart';
import '../../../data/models/nfc_client.dart';
import '../../../data/models/nfc_profile.dart';
import '../../../data/repositories/batch_repository.dart';

class BatchCreateScreen extends StatefulWidget {
  const BatchCreateScreen({super.key, required this.profile, required this.repository});
  final NfcProfile profile;
  final BatchRepository repository;

  @override
  State<BatchCreateScreen> createState() => _BatchCreateScreenState();
}

class _BatchCreateScreenState extends State<BatchCreateScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _codeMinController = TextEditingController(text: '4');
  final _codeMaxController = TextEditingController(text: '16');
  late Future<_FormOptions> _optionsFuture;
  String? _selectedClientId;
  CardFormat? _selectedFormat;
  String _codeCharset = 'digits';
  bool _lockAfterWrite = false;
  bool _saving = false;
  String? _error;

  static const _dataTypes = <String, String>{
    'url': 'Lien web',
    'text': 'Texte',
    'code': 'Code',
    'phone': 'Téléphone',
    'email': 'Email',
    'sms': 'SMS',
    'geo': 'Localisation',
    'contact': 'Contact (vCard)',
  };

  bool get _canCreate => widget.profile.role == NfcRole.admin ||
      (widget.profile.role == NfcRole.client && widget.profile.canCreateBatches && widget.profile.clientId != null);

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
  }

  Future<_FormOptions> _loadOptions() async {
    final formats = await widget.repository.listActiveFormats();
    if (widget.profile.role == NfcRole.admin) {
      return _FormOptions(clients: await widget.repository.listClients(), formats: formats);
    }
    return _FormOptions(clients: const [], formats: formats);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _codeMinController.dispose();
    _codeMaxController.dispose();
    super.dispose();
  }

  Future<void> _submit(String? adminClientId) async {
    if (!_canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Votre profil ne peut pas créer de dossier.')));
      return;
    }
    if (_saving) return;
    final format = _selectedFormat;
    final clientId = widget.profile.role == NfcRole.admin ? adminClientId : widget.profile.clientId;
    if (format == null || clientId == null) return;
    final rawQuantity = _quantityController.text.trim();
    final quantity = rawQuantity.isEmpty ? 0 : int.tryParse(rawQuantity);
    if (quantity == null) {
      setState(() => _error = 'La quantité doit être un nombre entier.');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final isCode = format.defaultDataType == 'code';
      await widget.repository.createBatch(
        clientId: clientId,
        formatId: format.id,
        name: _nameController.text,
        quantity: quantity,
        dataType: format.defaultDataType,
        lockAfterWrite: _lockAfterWrite,
        settings: isCode ? {
          'code_charset': _codeCharset,
          if (_codeMinController.text.trim().isNotEmpty) 'code_min': _codeMinController.text.trim(),
          if (_codeMaxController.text.trim().isNotEmpty) 'code_max': _codeMaxController.text.trim(),
        } : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dossier créé dans Supabase.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() { _saving = false; _error = _friendlyError(error); });
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCreate) {
      return Scaffold(
        appBar: AppBar(title: const Text('Créer un dossier')),
        body: const SafeArea(child: Center(child: Padding(padding: EdgeInsets.all(28), child: Text('La création de dossier n’est pas autorisée pour ce profil.', textAlign: TextAlign.center)))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un dossier')),
      body: SafeArea(child: FutureBuilder<_FormOptions>(
        future: _optionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _FormError(onRetry: () => setState(() => _optionsFuture = _loadOptions()));
          final options = snapshot.data!;
          final clients = options.clients;
          if (options.formats.isEmpty) return const _EmptyOptions(title: 'Aucun format disponible', message: 'Un administrateur doit activer au moins un format dans Supabase.');
          if (widget.profile.role == NfcRole.admin && clients.isEmpty) return const _EmptyOptions(title: 'Aucun client disponible', message: 'Ajoutez un client avant de créer un dossier.');
          if (_selectedFormat == null || !options.formats.any((format) => format.id == _selectedFormat!.id)) {
            _selectedFormat = options.formats.first;
            _lockAfterWrite = _selectedFormat!.lockDefault;
          }
          if (widget.profile.role == NfcRole.admin && !clients.any((client) => client.id == _selectedClientId)) {
            _selectedClientId = clients.first.id;
          }

          return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.1), borderRadius: BorderRadius.circular(18)),
                  child: Text(widget.profile.role == NfcRole.admin
                      ? 'Choisissez le client destinataire. Le rôle et les autorisations seront vérifiés par la RPC Supabase nfc_create_batch.'
                      : 'Ce dossier sera attribué à votre client. La RPC Supabase vérifie côté serveur que votre Admin vous a accordé ce droit.'),
                ),
                const SizedBox(height: 20),
                if (widget.profile.role == NfcRole.admin) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    decoration: const InputDecoration(labelText: 'Client destinataire', prefixIcon: Icon(Icons.business_outlined), border: OutlineInputBorder()),
                    items: clients.map((client) => DropdownMenuItem(value: client.id, child: Text(client.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _saving ? null : (value) => setState(() => _selectedClientId = value),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nom du dossier', hintText: 'Ex. Cartes IziCare — octobre', prefixIcon: Icon(Icons.folder_outlined), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CardFormat>(
                  value: _selectedFormat,
                  decoration: const InputDecoration(labelText: 'Format de carte', prefixIcon: Icon(Icons.credit_card_outlined), border: OutlineInputBorder()),
                  items: options.formats.map((format) => DropdownMenuItem(value: format, child: Text('${format.label} · ${format.chip}', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _saving ? null : (value) => setState(() {
                    _selectedFormat = value;
                    _lockAfterWrite = value?.lockDefault ?? false;
                  }),
                ),
                const SizedBox(height: 16),
                _FormatInfo(format: _selectedFormat!),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Type de données du format', prefixIcon: Icon(Icons.data_object_rounded), border: OutlineInputBorder()),
                  child: Text(_dataTypes[_selectedFormat!.defaultDataType] ?? _selectedFormat!.defaultDataType),
                ),
                if (_selectedFormat!.defaultDataType == 'code') ...[
                  const SizedBox(height: 16),
                  _CodeSettings(
                    charset: _codeCharset,
                    onCharsetChanged: (value) => setState(() => _codeCharset = value),
                    minController: _codeMinController,
                    maxController: _codeMaxController,
                  ),
                  const SizedBox(height: 8),
                  const Text('Le serveur vérifiera les caractères, la longueur et l’unicité de chaque code dans ce dossier.'),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cartes vierges', helperText: '0 si vous importez des données directement. Maximum 5000.', prefixIcon: Icon(Icons.numbers_rounded), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _lockAfterWrite,
                  onChanged: _saving ? null : (value) => setState(() => _lockAfterWrite = value),
                  title: const Text('Verrouiller après vérification'),
                  subtitle: const Text('Action définitive sur la carte physique.'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _submit(_selectedClientId),
                  icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Création…' : 'Créer le dossier'),
                ),
              ],
          );
        },
      )),
    );
  }
}

class _FormatInfo extends StatelessWidget {
  const _FormatInfo({required this.format});
  final CardFormat format;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${format.chip} · ${format.capacityBytes} octets disponibles', style: Theme.of(context).textTheme.titleSmall),
          if (format.fields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: format.fields.map((field) => Chip(label: Text('${field.label}${field.required ? ' *' : ''}'))).toList()),
          ],
          if (format.rules['required_any'] is List) ...[
            const SizedBox(height: 4),
            ...((format.rules['required_any'] as List).whereType<List>().map((group) {
              final labels = group.map((key) {
                final matches = format.fields.where((field) => field.key == key.toString());
                return matches.isEmpty ? key.toString() : matches.first.label;
              }).join(' / ');
              return Text('Au moins un de : $labels', style: Theme.of(context).textTheme.bodySmall);
            })),
          ],
        ]),
      );
}

class _CodeSettings extends StatelessWidget {
  const _CodeSettings({required this.charset, required this.onCharsetChanged, required this.minController, required this.maxController});
  final String charset;
  final ValueChanged<String> onCharsetChanged;
  final TextEditingController minController;
  final TextEditingController maxController;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    DropdownButtonFormField<String>(
      value: charset,
      decoration: const InputDecoration(labelText: 'Caractères autorisés', border: OutlineInputBorder()),
      items: const [DropdownMenuItem(value: 'digits', child: Text('Chiffres uniquement')), DropdownMenuItem(value: 'alnum', child: Text('Lettres et chiffres'))],
      onChanged: (value) { if (value != null) onCharsetChanged(value); },
    ),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: TextFormField(controller: minController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Longueur minimum', border: OutlineInputBorder()))),
      const SizedBox(width: 12),
      Expanded(child: TextFormField(controller: maxController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Longueur maximum', border: OutlineInputBorder()))),
    ]),
  ]);
}

class _FormOptions {
  const _FormOptions({required this.clients, required this.formats});
  final List<NfcClient> clients;
  final List<CardFormat> formats;
}

class _EmptyOptions extends StatelessWidget {
  const _EmptyOptions({required this.title, required this.message});
  final String title; final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.info_outline_rounded, size: 44), const SizedBox(height: 14), Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center),
  ])));
}

class _FormError extends StatelessWidget {
  const _FormError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('Impossible de charger les clients et formats.'), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
  ])));
}
