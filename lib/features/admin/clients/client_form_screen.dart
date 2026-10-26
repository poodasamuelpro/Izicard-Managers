import 'package:flutter/material.dart';

import '../../../data/repositories/client_repository.dart';

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, required this.repository});

  final ClientRepository repository;

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
      await widget.repository.inviteClient(
        fullName: _fullName.text,
        email: _email.text,
        clientName: _clientName.text,
        contactName: _contactName.text,
        phone: _phone.text,
      );
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                const Text(
                  'Créer le client et envoyer l’invitation',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le compte Auth, le profil client et le lien client_id sont créés par la fonction Supabase sécurisée. La clé service_role ne quitte jamais le serveur.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fullName,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                  validator: (value) => _required(value, 'Le nom complet'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail de connexion Auth',
                    helperText: 'Utilisé uniquement pour l’invitation et la connexion du compte.',
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _clientName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom du client / organisation'),
                  validator: (value) => _required(value, 'Le nom du client'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Contact (facultatif)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Téléphone (facultatif)'),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.mail_outline_rounded),
                  label: Text(_submitting ? 'Création et envoi…' : 'Créer et envoyer l’invitation'),
                ),
              ],
            ),
          ),
        ),
      );
}
