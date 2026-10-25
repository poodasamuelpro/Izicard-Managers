import 'package:flutter/material.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/repositories/auth_repository.dart';

class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updatePassword(_password.text);
      await widget.repository.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Impossible d’enregistrer le mot de passe. Le lien est peut-être expiré.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.lock_reset_rounded, size: 46, color: IzicardColors.cyan),
                          const SizedBox(height: 18),
                          Text('Activez votre accès IziCard', textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          const Text('Choisissez le mot de passe qui vous servira sur Android et sur le Web.', textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            autofocus: true,
                            decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                            validator: (value) => (value?.length ?? 0) < 8 ? 'Minimum 8 caractères.' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmation,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                            validator: (value) => value != _password.text ? 'Les mots de passe ne correspondent pas.' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving ? const CircularProgressIndicator() : const Text('Enregistrer et continuer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
