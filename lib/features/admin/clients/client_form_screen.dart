import 'package:flutter/material.dart';

import '../../../core/widgets/izi_ui.dart';

import '../../../data/repositories/client_repository.dart';

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, required this.repository, this.onCreated});

  final ClientRepository repository;

  /// Appelé avec l'identifiant du client créé (pour le présélectionner ailleurs).
  final void Function(String clientId)? onCreated;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _clientName = TextEditingController();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _clientName.dispose();
    _contactName.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label est obligatoire.' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await widget.repository.inviteClient(
        fullName: _fullName.text,
        email: _email.text,
        clientName: _clientName.text,
        contactName: _contactName.text,
        phone: _phone.text,
      );
      final createdId = created['client_id']?.toString();
      if (createdId != null && createdId.isNotEmpty) {
        widget.onCreated?.call(createdId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation envoyée à ${_email.text.trim()}.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inviter un client')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  const IziHero(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Nouveau client',
                    subtitle:
                        'Il reçoit un e-mail pour choisir son mot de passe et accéder à son espace.',
                  ),
                  const IziSectionTitle('Connexion'),
                  TextFormField(
                    controller: _fullName,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => _required(value, 'Le nom complet'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail de connexion',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                      helperText:
                          'Utilisé pour l’invitation et la connexion du client.',
                    ),
                    validator: (value) {
                      final required = _required(value, 'L’email');
                      if (required != null) return required;
                      final email = value!.trim();
                      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                          ? null
                          : 'Adresse email invalide.';
                    },
                  ),
                  const IziSectionTitle('Organisation'),
                  TextFormField(
                    controller: _clientName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom du client / organisation',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: (value) => _required(value, 'Le nom du client'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contactName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Contact (facultatif)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (facultatif)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    IziNotice(_error!, tone: IziTone.error),
                  ],
                ],
              ),
            ),
          ),
          IziBottomBar(
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon:
                  _submitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.mail_outline_rounded),
              label: Text(
                _submitting
                    ? 'Création et envoi…'
                    : 'Créer et envoyer l’invitation',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
