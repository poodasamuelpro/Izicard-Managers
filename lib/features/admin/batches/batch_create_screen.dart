import 'package:flutter/material.dart';

import '../../../core/theme/izicard_colors.dart';
import '../../../data/models/card_format.dart';
import '../../../data/models/nfc_client.dart';
import '../../../data/models/nfc_profile.dart';
import '../../../data/repositories/batch_repository.dart';

class BatchCreateScreen extends StatefulWidget {
  const BatchCreateScreen({
    super.key,
    required this.profile,
    required this.repository,
  });

  final NfcProfile profile;
  final BatchRepository repository;

  @override
  State<BatchCreateScreen> createState() => _BatchCreateScreenState();
}

class _BatchCreateScreenState extends State<BatchCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  late Future<_FormOptions> _optionsFuture;
  String? _selectedClientId;
  CardFormat? _selectedFormat;
  String? _selectedType;
  bool _lockAfterWrite = false;
  bool _saving = false;

  static const _dataTypes = <String, String>{
    'url': 'Lien web',
    'text': 'Texte',
    'phone': 'Téléphone',
    'email': 'Email',
    'sms': 'SMS',
    'geo': 'Localisation',
    'contact': 'Contact (vCard)',
  };

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
  }

  Future<_FormOptions> _loadOptions() async {
    if (widget.profile.role != NfcRole.admin) {
      return const _FormOptions(clients: [], formats: []);
    }
    final formats = await widget.repository.listActiveFormats();
    final clients = await widget.repository.listClients();
    return _FormOptions(clients: clients, formats: formats);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.profile.role != NfcRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seul un administrateur peut créer un dossier.')),
      );
      return;
    }
    if (_saving || !_formKey.currentState!.validate()) return;
    final format = _selectedFormat;
    final clientId = _selectedClientId;
    if (format == null || clientId == null) return;

    setState(() => _saving = true);
    try {
      await widget.repository.createBatch(
        clientId: clientId,
        formatId: format.id,
        name: _nameController.text,
        quantity: int.parse(_quantityController.text.trim()),
        dataType: _selectedType ?? format.defaultDataType,
        lockAfterWrite: _lockAfterWrite,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dossier créé dans Supabase.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Création impossible. Vérifiez les droits et réessayez.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.role != NfcRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Créer un dossier')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Seul un administrateur peut créer un dossier.',
                textAlign: TextAlign.center,
              ),
            ),
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
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _FormError(onRetry: () => setState(() => _optionsFuture = _loadOptions()));
              }
              final options = snapshot.data!;
              final activeClients = options.clients
                  .where((client) => client.active && !client.isExpired)
                  .toList();
              if (options.formats.isEmpty) {
                return const _EmptyOptions(
                  title: 'Aucun format de carte disponible',
                  message: 'Un administrateur doit activer au moins un format dans Supabase.',
                );
              }
              if (widget.profile.role == NfcRole.admin && activeClients.isEmpty) {
                return const _EmptyOptions(
                  title: 'Aucun client actif disponible',
                  message: 'Activez un client non expiré dans Supabase avant de créer un dossier.',
                );
              }
              if (_selectedFormat == null) {
                _selectedFormat = options.formats.first;
                _selectedType = _selectedFormat!.defaultDataType;
                _lockAfterWrite = _selectedFormat!.lockDefault;
              }
              if (widget.profile.role == NfcRole.admin) {
                if (!activeClients.any((client) => client.id == _selectedClientId)) {
                  _selectedClientId = activeClients.first.id;
                }
              }

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: IzicardColors.cyan.withOpacity(.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Ce dossier sera créé dans le backend Supabase partagé. Les règles d’accès sont vérifiées côté serveur.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.profile.role == NfcRole.admin) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedClientId,
                        decoration: const InputDecoration(
                          labelText: 'Client',
                          border: OutlineInputBorder(),
                        ),
                        items: activeClients
                            .map((client) => DropdownMenuItem(
                                  value: client.id,
                                  child: Text(client.name, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _selectedClientId = value),
                        validator: (value) => value == null ? 'Sélectionnez un client actif.' : null,
                      ),
                      const SizedBox(height: 16),
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
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Le nom est obligatoire.' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<CardFormat>(
                      value: _selectedFormat,
                      decoration: const InputDecoration(
                        labelText: 'Format de carte',
                        border: OutlineInputBorder(),
                      ),
                      items: options.formats
                          .map((format) => DropdownMenuItem(
                                value: format,
                                child: Text('${format.label} · ${format.chip}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                                _selectedFormat = value;
                                _selectedType = value?.defaultDataType;
                                _lockAfterWrite = value?.lockDefault ?? false;
                              }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type de données',
                        border: OutlineInputBorder(),
                      ),
                      items: _dataTypes.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ))
                          .toList(),
                      onChanged: _saving ? null : (value) => setState(() => _selectedType = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantité de cartes vierges',
                        helperText: '0 si vous importez ensuite des lignes en mode données directes. Maximum 5000.',
                        prefixIcon: Icon(Icons.numbers_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final quantity = int.tryParse(value?.trim() ?? '');
                        if (quantity == null || quantity < 0 || quantity > 5000) {
                          return 'Entrez un nombre compris entre 0 et 5000.';
                        }
                        if (quantity > 0 && _selectedType != 'url') {
                          return 'Les cartes vierges ne sont disponibles qu’en mode lien.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _lockAfterWrite,
                      onChanged: _saving ? null : (value) => setState(() => _lockAfterWrite = value),
                      title: const Text('Verrouiller après vérification'),
                      subtitle: const Text('Action définitive sur la carte physique.'),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'Création…' : 'Créer le dossier'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
  }
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
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 44),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _FormError extends StatelessWidget {
  const _FormError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger les clients et formats.'),
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
