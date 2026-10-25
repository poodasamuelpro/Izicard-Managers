import 'package:flutter/material.dart';

import '../../core/router/route_guards.dart';
import '../../data/models/nfc_profile.dart';

class NfcModuleScreen extends StatelessWidget {
  const NfcModuleScreen({
    super.key,
    required this.destination,
    required this.profile,
  });

  final NfcDestination destination;
  final NfcProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(destination.title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.construction_rounded,
                      size: 34,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    destination.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    destination.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Cette fonctionnalité est en cours de raccordement au '
                        'backend partagé du schéma nfc. Votre accès est '
                        'contrôlé selon le rôle ${profile.role.label.toLowerCase()}.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Retour à l’accueil'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
