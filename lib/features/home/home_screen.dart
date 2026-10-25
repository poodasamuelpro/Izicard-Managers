import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    final email = repository.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('IziCard NFC'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => repository.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset('assets/images/logo.jpg', height: 100),
            const SizedBox(height: 24),
            Text('Bienvenue', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(email),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Les dossiers NFC et l’écriture en série seront disponibles dans la prochaine étape.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
