import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/route_guards.dart';
import '../../core/theme/izicard_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/batch_repository.dart';
import '../batches/batches_screen.dart';
import '../verify/verify_tag_screen.dart';
import '../writing/write_screen.dart';

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

/// Coque de l'application : barre de navigation en bas (Accueil, Dossiers, Écrire, Vérifier, Menu).
/// Les onglets sont créés à la première visite puis conservés (l'état d'un écran n'est pas perdu
/// quand on change d'onglet). Le bouton retour ramène d'abord à l'accueil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.repository,
  });
  final NfcProfile profile;
  final AuthRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabHome = 0;
  static const _tabBatches = 1;
  static const _tabWrite = 2;
  static const _tabVerify = 3;
  static const _tabMenu = 4;

  int _index = _tabHome;
  final _visited = <int>{_tabHome};
  late final BatchRepository _batches = BatchRepository(
    Supabase.instance.client,
  );

  NfcProfile get _profile => widget.profile;
  AuthRepository get _repository => widget.repository;
  bool get _isAdmin => _profile.role == NfcRole.admin;

  void _go(int index) => setState(() {
    _index = index;
    _visited.add(index);
  });

  void _open(NfcDestination destination) => NfcRouteGuard.open(
    context,
    profile: _profile,
    destination: destination,
    repository: _repository,
  );

  /// Ouvre un écran : les 3 principaux ont leur onglet, les autres s'ouvrent par-dessus.
  void _openDestination(NfcDestination destination) {
    switch (destination) {
      case NfcDestination.batches:
        _go(_tabBatches);
      case NfcDestination.write:
        _go(_tabWrite);
      case NfcDestination.verify:
        _go(_tabVerify);
      default:
        _open(destination);
    }
  }

  Future<void> _confirmSignOut() async {
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
    if (shouldSignOut == true) await _repository.signOut();
  }

  /// Écrans disponibles pour ce profil (hors onglets fixes), dans l'ordre d'affichage.
  List<NfcDestination> get _menuDestinations => <NfcDestination>[
    if (_isAdmin) NfcDestination.dashboard,
    if (NfcDestination.createBatch.allowedFor(_profile))
      NfcDestination.createBatch,
    if (_isAdmin) NfcDestination.clients,
    NfcDestination.imports,
    if (_isAdmin) NfcDestination.export,
    NfcDestination.sync,
    NfcDestination.settings,
  ];

  Widget _page(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      _tabHome => _homeTab(context),
      _tabBatches => BatchesScreen(profile: _profile, repository: _batches),
      _tabWrite => WriteScreen(profile: _profile),
      _tabVerify => const VerifyTagScreen(),
      _ => _menuTab(context),
    };
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _index == _tabHome,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _go(_tabHome);
    },
    child: Scaffold(
      body: IndexedStack(
        index: _index,
        children: List<Widget>.generate(5, _page),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Dossiers',
          ),
          NavigationDestination(
            icon: Icon(Icons.nfc_rounded),
            label: 'Écrire',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Vérifier',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            label: 'Menu',
          ),
        ],
      ),
    ),
  );

  // ----- Onglet Accueil -----
  Widget _homeTab(BuildContext context) {
    const quick = [NfcDestination.write, NfcDestination.verify];
    final others = <NfcDestination>[
      NfcDestination.batches,
      ..._menuDestinations,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('IziCard Manager'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              tooltip: 'Se déconnecter',
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          padding: EdgeInsets.zero,
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _WelcomeCard(
                    name: _profile.displayName,
                    email: _repository.currentUser?.email ?? '',
                    role: _profile.role,
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
                            onTap: () => _openDestination(quick[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _isAdmin ? 'Gestion' : 'Votre espace',
                    style: titleStyle,
                  ),
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
                                  onTap: () => _openDestination(destination),
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

  // ----- Onglet Menu -----
  Widget _menuTab(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: SafeArea(
        child: ResponsiveContent(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.person_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    _profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_repository.currentUser?.email ?? ''}\n${_profile.role.label}',
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 16),
              ..._menuDestinations.map(
                (destination) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _destinationIcon(destination),
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        destination.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(_destinationHint(destination)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(destination),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Se déconnecter'),
              ),
            ],
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
