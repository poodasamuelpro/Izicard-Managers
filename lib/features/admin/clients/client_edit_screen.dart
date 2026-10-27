import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/nfc_client.dart';
import '../../../data/repositories/client_repository.dart';

/// Modification des coordonnées d'un client existant (nom, contact, e-mail, téléphone).
/// Les accès (actif, expiration) se gèrent depuis la liste des clients.
class ClientEditScreen extends StatefulWidget {
  const ClientEditScreen({
    super.key,
    required this.client,
    required this.repository,
  });

  final NfcClient client;
  final ClientRepository repository;

  @override
  State<ClientEditScreen> createState() => _ClientEditScreenState();
}

class _ClientEditScreenState extends State<ClientEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.client.name);
  late final _contact = TextEditingController(
    text: widget.client.contactName ?? '',
  );
  late final _email = TextEditingController(text: widget.client.email ?? '');
  late final _phone = TextEditingController(text: widget.client.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim() != widget.client.name ||
      _contact.text.trim() != (widget.client.contactName ?? '') ||
      _email.text.trim() != (widget.client.email ?? '') ||
      _phone.text.trim() != (widget.client.phone ?? '');

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateClient(
        clientId: widget.client.id,
        name: _name.text,
        contactName: _contact.text,
        email: _email.text,
        phone: _phone.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client mis à jour.')));
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error =
                  'Enregistrement impossible. Vérifiez votre connexion puis réessayez.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Modifier le client')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom du client *',
                    border: OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          (value ?? '').trim().isEmpty
                              ? 'Le nom est obligatoire.'
                              : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contact,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Personne de contact',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail de contact',
                    helperText:
                        'Ne modifie pas l’e-mail de connexion du compte.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                        ? null
                        : 'E-mail invalide.';
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: _saving ? null : _save,
                  icon:
                      _saving
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_rounded),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
