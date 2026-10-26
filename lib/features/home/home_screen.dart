import 'package:flutter/material.dart';

import '../../core/router/route_guards.dart';
import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.profile, required this.repository});
  final NfcProfile profile;
  final AuthRepository repository;
  @override
  Widget build(BuildContext context) => HomeScreen(profile: profile, repository: repository);
}

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key, required this.profile, required this.repository});
  final NfcProfile profile;
  final AuthRepository repository;
  @override
  Widget build(BuildContext context) => HomeScreen(profile: profile, repository: repository);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.profile, required this.repository});
  final NfcProfile profile;
  final AuthRepository repository;

  bool get _isAdmin => profile.role == NfcRole.admin;

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Se déconnecter ?'),
        content: const Text('Votre session sera fermée sur cet appareil.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Déconnexion')),
        ],
      ),
    );
    if (shouldSignOut == true) await repository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _isAdmin
        ? <NfcDestination>[
            NfcDestination.createBatch,
            NfcDestination.batches,
            NfcDestination.clients,
            NfcDestination.imports,
            NfcDestination.export,
            NfcDestination.write,
            NfcDestination.verify,
            NfcDestination.sync,
            NfcDestination.settings,
          ]
        : <NfcDestination>[
            if (profile.canCreateBatches && profile.clientId != null) NfcDestination.createBatch,
            NfcDestination.batches,
            NfcDestination.imports,
            NfcDestination.write,
            NfcDestination.verify,
            NfcDestination.sync,
            NfcDestination.settings,
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('IziCard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              tooltip: 'Se déconnecter',
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _WelcomeCard(
                name: profile.displayName,
                email: repository.currentUser?.email ?? '',
                role: profile.role,
                isWide: constraints.maxWidth >= 600,
              ),
              const SizedBox(height: 28),
              Text(_isAdmin ? 'Espace administration' : 'Votre espace NFC',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                _isAdmin
                    ? 'Gérez les opérations IziCard depuis votre mobile.'
                    : 'Retrouvez vos dossiers et vos opérations NFC autorisées.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: IzicardColors.muted),
              ),
              const SizedBox(height: 18),
              ...destinations.map((destination) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DestinationCard(
                      destination: destination,
                      onTap: () => NfcRouteGuard.open(context, profile: profile, destination: destination),
                    ),
                  )),
              const SizedBox(height: 8),
              Text('Les données et les autorisations sont gérées par le backend IziCard partagé.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IzicardColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name, required this.email, required this.role, required this.isWide});
  final String name;
  final String email;
  final NfcRole role;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(isWide ? 28 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [IzicardColors.cyan, IzicardColors.blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: IzicardColors.cyan.withOpacity(0.16), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.white.withOpacity(0.2), child: const Icon(Icons.nfc_rounded, color: Colors.white, size: 30)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bonjour, $name', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.9))),
                ],
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(color: colors.surface.withOpacity(0.18), borderRadius: BorderRadius.circular(30)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(role.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination, required this.onTap});
  final NfcDestination destination;
  final VoidCallback onTap;

  IconData get _icon => switch (destination) {
        NfcDestination.clients => Icons.people_alt_outlined,
        NfcDestination.batches => Icons.inventory_2_outlined,
        NfcDestination.createBatch => Icons.add_box_outlined,
        NfcDestination.imports => Icons.upload_file_outlined,
        NfcDestination.export => Icons.download_outlined,
        NfcDestination.write => Icons.nfc_rounded,
        NfcDestination.verify => Icons.fact_check_outlined,
        NfcDestination.sync => Icons.sync_rounded,
        NfcDestination.settings => Icons.settings_outlined,
      };

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: IzicardColors.paleCyan, borderRadius: BorderRadius.circular(15)), child: Icon(_icon, color: IzicardColors.cyan)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(destination.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(destination.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IzicardColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}
