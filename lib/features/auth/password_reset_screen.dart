import 'package:flutter/material.dart';

import '../../core/widgets/izi_ui.dart';

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
      if (mounted) {
        setState(() => _error = 'Impossible de modifier le mot de passe.');
      }
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

  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Réinitialiser le mot de passe',
      'Entrer le code',
      'Nouveau mot de passe',
    ];
    final icons = [
      Icons.mark_email_unread_outlined,
      Icons.pin_outlined,
      Icons.lock_reset_rounded,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_step])),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  IziProgress(value: (_step + 1) / 3, height: 6),
                  const SizedBox(height: 4),
                  Text(
                    'Étape ${_step + 1} sur 3',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  IziHero(
                    icon: icons[_step],
                    title: titles[_step],
                    subtitle:
                        _step == 0
                            ? 'Saisissez votre email pour recevoir un code de 8 chiffres.'
                            : _step == 1
                            ? 'Le code a été envoyé à ${_emailController.text}.'
                            : 'Choisissez un nouveau mot de passe sécurisé (8 caractères minimum).',
                  ),
                  const SizedBox(height: 22),
                  if (_step == 0)
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Adresse email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                  if (_step == 1)
                    TextField(
                      controller: _codeController,
                      autofocus: true,
                      maxLength: 8,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Code à 8 chiffres',
                        counterText: '',
                      ),
                    ),
                  if (_step == 2)
                    TextField(
                      controller: _passwordController,
                      autofocus: true,
                      obscureText: _hidden,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _hidden ? 'Afficher' : 'Masquer',
                          onPressed: () => setState(() => _hidden = !_hidden),
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    IziNotice(_error!, tone: IziTone.error),
                  ],
                ],
              ),
            ),
            IziBottomBar(
              child: FilledButton(
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
            ),
          ],
        ),
      ),
    );
  }
}
