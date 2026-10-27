import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  int _step = 0;
  bool _completed = false;
  bool _loading = false;
  String? _error;

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Saisis une adresse email valide.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.requestPasswordReset(email);
      setState(() => _step = 1);
    } catch (_) {
      setState(() => _error = 'Impossible d’envoyer le code. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      setState(() => _error = 'Le code doit contenir exactement 8 chiffres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.verifyRecoveryCode(
        email: _emailController.text,
        token: code,
      );
      setState(() => _step = 2);
    } catch (_) {
      setState(() => _error = 'Code invalide ou expiré.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(
        () => _error = 'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.updatePassword(password);
      _completed = true;
      // Ferme la session ouverte par le code : l'utilisateur se reconnecte avec son nouveau mot de passe.
      await widget.repository.signOut();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour.')),
        );
      }
    } catch (_) {
      setState(() => _error = 'Impossible de modifier le mot de passe.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    // Abandon après la vérification du code : ne pas laisser une session ouverte.
    if (_step == 2 && !_completed) {
      widget.repository.signOut();
    }
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Réinitialiser le mot de passe',
      'Entrer le code',
      'Nouveau mot de passe',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_step])),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _step == 0
                  ? 'Saisis ton email pour recevoir un code de 8 chiffres.'
                  : _step == 1
                  ? 'Le code a été envoyé à ${_emailController.text}.'
                  : 'Choisis un nouveau mot de passe sécurisé.',
            ),
            const SizedBox(height: 24),
            if (_step == 0)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Adresse email'),
              ),
            if (_step == 1)
              TextField(
                controller: _codeController,
                autofocus: true,
                maxLength: 8,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Code à 8 chiffres',
                  counterText: '',
                ),
              ),
            if (_step == 2)
              TextField(
                controller: _passwordController,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed:
                  _loading
                      ? null
                      : (_step == 0
                          ? _sendCode
                          : _step == 1
                          ? _verifyCode
                          : _changePassword),
              child:
                  _loading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        _step == 0
                            ? 'Envoyer le code'
                            : _step == 1
                            ? 'Vérifier le code'
                            : 'Enregistrer',
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
