import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/route_guards.dart';
import '../../core/theme/izicard_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/batch_repository.dart';
import '../../core/widgets/izi_ui.dart';
import '../../data/models/nfc_batch.dart';
import '../batches/batch_detail_screen.dart';
import '../batches/batch_source.dart';
import '../batches/batches_screen.dart';
import '../import/import_screen.dart';
import '../writing/quick_write_screen.dart';
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
  late Future<BatchList> _homeData = loadBatches(_batches);

  Future<void> _reloadHome() async {
    setState(() => _homeData = loadBatches(_batches));
    try {
      await _homeData;
    } catch (_) {}
  }

  void _openBatch(NfcBatch batch) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder:
                (_) => BatchDetailScreen(
                  batch: batch,
                  profile: _profile,
                  repository: _batches,
                  onImport:
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => ImportScreen(
                                profile: _profile,
                                repository: _batches,
                                initialBatchId: batch.id,
                              ),
                        ),
                      ),
                ),
          ),
        )
        .then((_) => _reloadHome());
  }

  void _quickWrite() => Navigator.of(context)
      .push<void>(
        MaterialPageRoute<void>(
          builder:
              (_) => QuickWriteScreen(profile: _profile, repository: _batches),
        ),
      )
      .then((_) => _reloadHome());

  void _import() => Navigator.of(context)
      .push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ImportScreen(profile: _profile, repository: _batches),
        ),
      )
      .then((_) => _reloadHome());

  Widget _homeTab(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('IziCard Manager'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Actualiser',
              onPressed: _reloadHome,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reloadHome,
          child: ResponsiveContent(
            padding: EdgeInsets.zero,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Bonjour, ${_profile.displayName}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _isAdmin ? 'Espace administration' : 'Votre espace NFC',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const IziSectionTitle('Actions rapides'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _HomeAction(
                        icon: Icons.nfc_rounded,
                        title: 'Écrire une carte',
                        hint: 'Lien, texte ou numéro',
                        filled: true,
                        onTap: _quickWrite,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HomeAction(
                        icon: Icons.fact_check_rounded,
                        title: 'Vérifier un tag',
                        hint: 'Lire et contrôler',
                        onTap: () => _go(_tabVerify),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                IziItemCard(
                  icon: Icons.upload_file_rounded,
                  title: 'Importer des données',
                  subtitle: 'Fichier Excel/CSV ou saisie, vers un dossier de cartes',
                  onTap: _import,
                ),
                FutureBuilder<BatchList>(
                  future: _homeData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: IziNotice(
                          'Impossible de charger vos dossiers. Tirez vers le bas pour réessayer.',
                          tone: IziTone.warning,
                          icon: Icons.cloud_off_rounded,
                        ),
                      );
                    }
                    final batches = (snapshot.data?.batches ?? const <NfcBatch>[])
                        .where((b) => b.status != 'archived')
                        .toList();
                    return _homeSummary(context, batches);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeSummary(BuildContext context, List<NfcBatch> batches) {
    final ink = context.ink;
    if (batches.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IziSectionTitle('Pour commencer'),
          const IziNotice(
            'Importez vos données (ou écrivez une carte unique) : un dossier est alors créé pour regrouper vos cartes.',
            title: 'Aucun dossier pour le moment',
          ),
          const SizedBox(height: 10),
          if (NfcDestination.createBatch.allowedFor(_profile))
            OutlinedButton.icon(
              onPressed: () => _open(NfcDestination.createBatch),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Créer un dossier'),
            ),
        ],
      );
    }
    int sum(int Function(NfcBatch) pick) =>
        batches.fold<int>(0, (a, b) => a + pick(b));
    final pending = sum((b) => b.pending);
    final verified = sum((b) => b.verified);
    final errors = sum((b) => b.errors);
    final total = sum((b) => b.total);
    final todo =
        batches.where((b) => b.pending > 0 || b.errors > 0).toList()
          ..sort((a, b) => (b.pending + b.errors).compareTo(a.pending + a.errors));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IziSectionTitle(
          'Vos cartes',
          action: TextButton(
            onPressed: () => _go(_tabBatches),
            child: Text('${batches.length} dossier(s)'),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 4 : 2;
            final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
            Widget cell(Widget child) => SizedBox(width: width, child: child);
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                cell(IziStat(value: '$total', label: 'Cartes au total', icon: Icons.layers_outlined)),
                cell(IziStat(value: '$pending', label: 'À écrire', icon: Icons.edit_note_rounded, color: ink.pending)),
                cell(IziStat(value: '$verified', label: 'Vérifiées', icon: Icons.verified_rounded, color: ink.verified)),
                cell(IziStat(value: '$errors', label: 'En erreur', icon: Icons.error_outline_rounded, color: ink.error)),
              ],
            );
          },
        ),
        if (total > 0) ...[
          const SizedBox(height: 12),
          IziProgress(value: verified / total, height: 10),
          const SizedBox(height: 4),
          Text(
            '${(verified * 100 / total).round()} % des cartes vérifiées',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const IziSectionTitle('À traiter'),
        if (todo.isEmpty)
          const IziNotice(
            'Rien à écrire ni à corriger pour le moment.',
            tone: IziTone.success,
          )
        else
          ...todo
              .take(4)
              .map(
                (batch) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IziItemCard(
                    icon: Icons.inventory_2_outlined,
                    title: batch.name,
                    subtitle:
                        '${batch.pending} à écrire${batch.errors > 0 ? ' · ${batch.errors} en erreur' : ''}',
                    onTap: () => _openBatch(batch),
                  ),
                ),
              ),
      ],
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

/// Grande action de l'accueil : une seule touche, pensée pour le pouce.
class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String title;
  final String hint;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = filled ? Colors.white : colors.onSurface;
    final secondary =
        filled ? Colors.white.withOpacity(0.88) : colors.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
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
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: colors.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        filled
                            ? Colors.white.withOpacity(0.2)
                            : colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: filled ? Colors.white : colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
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
