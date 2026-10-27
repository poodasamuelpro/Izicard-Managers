import 'package:flutter/material.dart';

import '../../core/router/route_guards.dart';
import '../../core/theme/izicard_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/auth_repository.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({
    super.key,
    required this.profile,
    required this.repository,
  });
  final NfcProfile profile;
  final AuthRepository repository;
  @override
  Widget build(BuildContext context) =>
      HomeScreen(profile: profile, repository: repository);
}

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({
    super.key,
    required this.profile,
    required this.repository,
  });
  final NfcProfile profile;
  final AuthRepository repository;
  @override
  Widget build(BuildContext context) =>
      HomeScreen(profile: profile, repository: repository);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.repository,
  });
  final NfcProfile profile;
  final AuthRepository repository;

  bool get _isAdmin => profile.role == NfcRole.admin;

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: const Icon(Icons.logout_rounded),
            title: const Text('Se déconnecter ?'),
            content: const Text('Votre session sera fermée sur cet appareil.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Déconnexion'),
              ),
            ],
          ),
    );
    if (shouldSignOut == true) await repository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final destinations =
        _isAdmin
            ? <NfcDestination>[
              NfcDestination.dashboard,
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
              if (profile.canCreateBatches && profile.clientId != null)
                NfcDestination.createBatch,
              NfcDestination.batches,
              NfcDestination.imports,
              NfcDestination.write,
              NfcDestination.verify,
              NfcDestination.sync,
              NfcDestination.settings,
            ];

    const quick = [NfcDestination.write, NfcDestination.verify];
    final others = destinations.where((d) => !quick.contains(d)).toList();
    void open(BuildContext context, NfcDestination destination) =>
        NfcRouteGuard.open(
          context,
          profile: profile,
          destination: destination,
          repository: repository,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('IziCard Manager'),
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
        child: ResponsiveContent(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : 2;
              const gap = 12.0;
              final tileWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final titleStyle = Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _WelcomeCard(
                    name: profile.displayName,
                    email: repository.currentUser?.email ?? '',
                    role: profile.role,
                    isWide: constraints.maxWidth >= 600,
                  ),
                  const SizedBox(height: 24),
                  Text('Actions rapides', style: titleStyle),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < quick.length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        Expanded(
                          child: _QuickAction(
                            destination: quick[i],
                            filled: i == 0,
                            onTap: () => open(context, quick[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(_isAdmin ? 'Gestion' : 'Votre espace', style: titleStyle),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children:
                        others
                            .map(
                              (destination) => SizedBox(
                                width: tileWidth,
                                child: _GridTile(
                                  destination: destination,
                                  onTap: () => open(context, destination),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vos données sont synchronisées et protégées par votre compte IziCard.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.name,
    required this.email,
    required this.role,
    required this.isWide,
  });
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
        gradient: LinearGradient(
          colors: context.ink.hero,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.nfc_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      role.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

IconData _destinationIcon(NfcDestination destination) => switch (destination) {
  NfcDestination.clients => Icons.people_alt_rounded,
  NfcDestination.batches => Icons.inventory_2_rounded,
  NfcDestination.createBatch => Icons.create_new_folder_rounded,
  NfcDestination.imports => Icons.upload_file_rounded,
  NfcDestination.export => Icons.download_rounded,
  NfcDestination.write => Icons.nfc_rounded,
  NfcDestination.verify => Icons.fact_check_rounded,
  NfcDestination.sync => Icons.sync_rounded,
  NfcDestination.settings => Icons.settings_rounded,
  NfcDestination.dashboard => Icons.dashboard_rounded,
};

String _destinationHint(NfcDestination destination) => switch (destination) {
  NfcDestination.clients => 'Accès et invitations',
  NfcDestination.batches => 'Vos lots de cartes',
  NfcDestination.createBatch => 'Nouveau lot de cartes',
  NfcDestination.imports => 'Fichier ou saisie',
  NfcDestination.export => 'Données et rapports',
  NfcDestination.write => 'Dossier ou carte unique',
  NfcDestination.verify => 'Lisez et contrôlez un tag',
  NfcDestination.sync => 'Envois en attente',
  NfcDestination.settings => 'Compte et préférences',
  NfcDestination.dashboard => 'Vue d’ensemble',
};

/// Grande action de l'accueil (écrire / vérifier) : pensée pour le pouce, une seule touche.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.destination,
    required this.filled,
    required this.onTap,
  });
  final NfcDestination destination;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = filled ? Colors.white : colors.onSurface;
    final secondary = filled ? Colors.white.withOpacity(0.88) : colors.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          gradient:
              filled
                  ? LinearGradient(
                    colors: context.ink.hero,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: filled ? null : colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
          border: filled ? null : Border.all(color: colors.outlineVariant),
          boxShadow:
              filled
                  ? [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        filled
                            ? Colors.white.withOpacity(0.2)
                            : colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _destinationIcon(destination),
                    color: filled ? Colors.white : colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  destination.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _destinationHint(destination),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuile compacte (grille 2 colonnes sur téléphone) : icône, titre, précision courte.
class _GridTile extends StatelessWidget {
  const _GridTile({required this.destination, required this.onTap});
  final NfcDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 124),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _destinationIcon(destination),
                    size: 22,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  destination.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _destinationHint(destination),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
