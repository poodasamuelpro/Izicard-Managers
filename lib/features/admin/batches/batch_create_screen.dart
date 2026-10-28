import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/izicard_colors.dart';
import '../../../core/widgets/izi_ui.dart';
import '../../../data/models/card_format.dart';
import '../../../data/models/nfc_client.dart';
import '../../../data/models/nfc_profile.dart';
import '../../../data/repositories/batch_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../clients/client_form_screen.dart';

class BatchCreateScreen extends StatefulWidget {
  const BatchCreateScreen({
    super.key,
    required this.profile,
    required this.repository,
    this.initialClientId,
  });
  final NfcProfile profile;
  final BatchRepository repository;

  /// Client présélectionné (ex. depuis la fiche d'un client).
  final String? initialClientId;

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
  String? _internalClientId;
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

  bool get _canCreate =>
      widget.profile.role == NfcRole.admin ||
      (widget.profile.role == NfcRole.client &&
          widget.profile.canCreateBatches &&
          widget.profile.clientId != null);

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
  }

  Future<_FormOptions> _loadOptions() async {
    final formats = await widget.repository.listActiveFormats();
    if (widget.profile.role == NfcRole.admin) {
      try {
        _internalClientId = await widget.repository.ensureInternalClient();
      } catch (_) {
        _internalClientId = null; // l'admin peut toujours choisir un client existant
      }
      return _FormOptions(
        clients: await widget.repository.listClients(),
        formats: formats,
      );
    }
    return _FormOptions(clients: const [], formats: formats);
  }

  /// Crée un client sans quitter la page, puis le présélectionne.
  Future<void> _inviteClient() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => ClientFormScreen(
              repository: ClientRepository(Supabase.instance.client),
              onCreated: (id) => _selectedClientId = id,
            ),
      ),
    );
    if (created == true && mounted) {
      setState(() => _optionsFuture = _loadOptions());
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre profil ne peut pas créer de dossier.'),
        ),
      );
      return;
    }
    if (_saving) return;
    final format = _selectedFormat;
    final clientId =
        widget.profile.role == NfcRole.admin
            ? adminClientId
            : widget.profile.clientId;
    if (format == null || clientId == null) return;
    final rawQuantity = _quantityController.text.trim();
    final quantity = rawQuantity.isEmpty ? 0 : int.tryParse(rawQuantity);
    if (quantity == null) {
      setState(() => _error = 'La quantité doit être un nombre entier.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final isCode = format.defaultDataType == 'code';
      await widget.repository.createBatch(
        clientId: clientId,
        formatId: format.id,
        name: _nameController.text,
        quantity: quantity,
        dataType: format.defaultDataType,
        lockAfterWrite: _lockAfterWrite,
        settings:
            isCode
                ? {
                  'code_charset': _codeCharset,
                  if (_codeMinController.text.trim().isNotEmpty)
                    'code_min': _codeMinController.text.trim(),
                  if (_codeMaxController.text.trim().isNotEmpty)
                    'code_max': _codeMaxController.text.trim(),
                }
                : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dossier créé.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendlyError(error);
      });
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
        body: const SafeArea(
          child: IziEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Création non autorisée',
            message: 'Votre profil ne permet pas de créer un dossier.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un dossier')),
      body: SafeArea(
        child: FutureBuilder<_FormOptions>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return _FormError(
                onRetry: () => setState(() => _optionsFuture = _loadOptions()),
              );
            final options = snapshot.data!;
            final clients = options.clients;
            if (options.formats.isEmpty)
              return const _EmptyOptions(
                title: 'Aucun format disponible',
                message:
                    'Aucun format de carte n’est actif. Contactez votre administrateur.',
              );
            if (widget.profile.role == NfcRole.admin && clients.isEmpty)
              return IziEmptyState(
                icon: Icons.group_add_outlined,
                title: 'Aucun client pour le moment',
                message: 'Invitez un client, puis revenez créer son dossier.',
                actionLabel: 'Nouveau client',
                actionIcon: Icons.person_add_alt_1_rounded,
                onAction: _inviteClient,
              );
            if (_selectedFormat == null ||
                !options.formats.any(
                  (format) => format.id == _selectedFormat!.id,
                )) {
              _selectedFormat = options.formats.first;
              _lockAfterWrite = _selectedFormat!.lockDefault;
            }
            if (widget.profile.role == NfcRole.admin &&
                !clients.any((client) => client.id == _selectedClientId)) {
              final preferred = [widget.initialClientId, _internalClientId]
                  .whereType<String>()
                  .where((id) => clients.any((client) => client.id == id));
              _selectedClientId =
                  preferred.isNotEmpty ? preferred.first : clients.first.id;
            }

            final form = ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                IziNotice(
                  widget.profile.role == NfcRole.admin
                      ? 'Choisissez le client destinataire, ou « Mes propres cartes » pour vos cartes personnelles (sans client externe).'
                      : 'Ce dossier sera créé pour votre propre compte client.',
                ),
                const IziSectionTitle('Destinataire et nom'),
                if (widget.profile.role == NfcRole.admin) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'Client destinataire',
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items:
                        clients
                            .map(
                              (client) => DropdownMenuItem(
                                value: client.id,
                                child: Text(
                                  client.id == _internalClientId
                                      ? 'Mes propres cartes (usage interne)'
                                      : client.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _saving
                            ? null
                            : (value) =>
                                setState(() => _selectedClientId = value),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _inviteClient,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Nouveau client'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nom du dossier',
                    hintText: 'Ex. Cartes IziCare — octobre',
                    prefixIcon: Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const IziSectionTitle('Format de carte'),
                DropdownButtonFormField<CardFormat>(
                  value: _selectedFormat,
                  decoration: const InputDecoration(
                    labelText: 'Format de carte',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items:
                      options.formats
                          .map(
                            (format) => DropdownMenuItem(
                              value: format,
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
                          : (value) => setState(() {
                            _selectedFormat = value;
                            _lockAfterWrite = value?.lockDefault ?? false;
                          }),
                ),
                const SizedBox(height: 16),
                _FormatInfo(format: _selectedFormat!),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Type de données du format',
                    prefixIcon: Icon(Icons.data_object_rounded),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dataTypes[_selectedFormat!.defaultDataType] ??
                        _selectedFormat!.defaultDataType,
                  ),
                ),
                if (_selectedFormat!.defaultDataType == 'code') ...[
                  const SizedBox(height: 16),
                  _CodeSettings(
                    charset: _codeCharset,
                    onCharsetChanged:
                        (value) => setState(() => _codeCharset = value),
                    minController: _codeMinController,
                    maxController: _codeMaxController,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chaque code est contrôlé : caractères autorisés, longueur et unicité dans ce dossier.',
                  ),
                ],
                const IziSectionTitle('Quantité et sécurité'),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cartes vierges',
                    helperText:
                        '0 si vous importez des données directement. Maximum 5000.',
                    prefixIcon: Icon(Icons.numbers_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _lockAfterWrite,
                  onChanged:
                      _saving
                          ? null
                          : (value) => setState(() => _lockAfterWrite = value),
                  title: const Text('Verrouiller après vérification'),
                  subtitle: const Text(
                    'Action définitive sur la carte physique.',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  IziNotice(_error!, tone: IziTone.error),
                ],
              ],
            );
            return Column(
              children: [
                Expanded(child: form),
                IziBottomBar(
                  child: FilledButton.icon(
                    onPressed:
                        _saving ? null : () => _submit(_selectedClientId),
                    icon:
                        _saving
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Création…' : 'Créer le dossier'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FormatInfo extends StatelessWidget {
  const _FormatInfo({required this.format});
  final CardFormat format;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withOpacity(.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${format.chip} · ${format.capacityBytes} octets disponibles',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (format.fields.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                format.fields
                    .map(
                      (field) => Chip(
                        label: Text(
                          '${field.label}${field.required ? ' *' : ''}',
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
        if (format.rules['required_any'] is List) ...[
          const SizedBox(height: 4),
          ...((format.rules['required_any'] as List).whereType<List>().map((
            group,
          ) {
            final labels = group
                .map((key) {
                  final matches = format.fields.where(
                    (field) => field.key == key.toString(),
                  );
                  return matches.isEmpty ? key.toString() : matches.first.label;
                })
                .join(' / ');
            return Text(
              'Au moins un de : $labels',
              style: Theme.of(context).textTheme.bodySmall,
            );
          })),
        ],
      ],
    ),
  );
}

class _CodeSettings extends StatelessWidget {
  const _CodeSettings({
    required this.charset,
    required this.onCharsetChanged,
    required this.minController,
    required this.maxController,
  });
  final String charset;
  final ValueChanged<String> onCharsetChanged;
  final TextEditingController minController;
  final TextEditingController maxController;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        value: charset,
        decoration: const InputDecoration(
          labelText: 'Caractères autorisés',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'digits', child: Text('Chiffres uniquement')),
          DropdownMenuItem(value: 'alnum', child: Text('Lettres et chiffres')),
        ],
        onChanged: (value) {
          if (value != null) onCharsetChanged(value);
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Longueur minimum',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Longueur maximum',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _FormOptions {
  const _FormOptions({required this.clients, required this.formats});
  final List<NfcClient> clients;
  final List<CardFormat> formats;
}

class _EmptyOptions extends StatelessWidget {
  const _EmptyOptions({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) =>
      IziEmptyState(icon: Icons.info_outline_rounded, title: title, message: message);
}

class _FormError extends StatelessWidget {
  const _FormError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => IziErrorState(
    message: 'Impossible de charger les clients et les formats.',
    onRetry: onRetry,
  );
}
