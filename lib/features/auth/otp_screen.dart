import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email, required this.repository});

  final String email;
  final AuthRepository repository;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
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
      await widget.repository.verifyOtp(email: widget.email, token: code);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = 'Code invalide ou expiré.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Code envoyé à ${widget.email}'),
            const SizedBox(height: 20),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFC62828))),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Valider le code'),
            ),
          ],
        ),
      ),
    );
  }
}
