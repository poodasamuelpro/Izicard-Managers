import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/izicard_theme.dart';
import 'core/network/connectivity_service.dart';
import 'data/local/app_database.dart';
import 'data/models/nfc_profile.dart';
import 'data/remote/tags_remote.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'services/sync/sync_worker.dart';
import 'features/auth/access_revoked_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/password_setup_screen.dart';

class IzicardApp extends StatelessWidget {
  const IzicardApp({super.key, this.configurationError = false});

  final bool configurationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IziCard NFC',
      theme: IzicardTheme.light,
      darkTheme: IzicardTheme.light,
      themeMode: ThemeMode.light,
      locale: const Locale('fr'),
      home: configurationError
          ? const ConfigurationErrorScreen()
          : const AuthGate(),
    );
  }
}

class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Configuration Supabase manquante',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ajoutez SUPABASE_URL et SUPABASE_ANON_KEY à la '
                  'configuration de build. Aucun secret serveur ne doit être '
                  'embarqué dans l’application.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final AuthRepository _repository;
  late final AppDatabase _database;
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  Future<NfcProfile?>? _profileFuture;
  bool _passwordSetup = false;
  SyncWorker? _worker;
  String? _workerUserId;
  Timer? _accessTimer;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _repository = AuthRepository(
      Supabase.instance.client,
      database: _database,
    );
    _user = _repository.currentUser;
    _profileFuture = _futureFor(_user);
    _authSubscription = _repository.authStateChanges.listen(_onAuthChanged);
    WidgetsBinding.instance.addObserver(this);
    // Contrôle régulier de l'accès : une révocation doit se voir sans redémarrer l'application.
    _accessTimer = Timer.periodic(const Duration(minutes: 2), (_) => unawaited(_recheckAccess()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_recheckAccess());
  }

  /// Charge le profil ; démarre la synchro seulement pour un accès valide, l'arrête sinon.
  Future<NfcProfile?>? _futureFor(User? user) {
    if (user == null) {
      unawaited(_stopWorker());
      return null;
    }
    return _repository.loadProfile(user.id).then((profile) {
      if (profile != null && profile.hasValidAccess) {
        unawaited(_startWorker(user.id));
      } else {
        unawaited(_stopWorker());
      }
      return profile;
    });
  }

  Future<void> _startWorker(String userId) async {
    if (_workerUserId == userId && _worker != null) return;
    await _stopWorker();
    final worker = SyncWorker(
      connectivity: ConnectivityService(),
      repository: SyncRepository(
        database: _database,
        remote: TagsRemote(Supabase.instance.client),
        userId: userId,
      ),
    );
    _worker = worker;
    _workerUserId = userId;
    await worker.start();
  }

  /// Arrête l'envoi sans toucher à la file : elle reste intacte pour son propriétaire.
  Future<void> _stopWorker() async {
    final worker = _worker;
    _worker = null;
    _workerUserId = null;
    await worker?.dispose();
  }

  /// Recontrôle l'accès en cours de session. Si l'accès est retiré ou expiré, on
  /// ferme tous les écrans ouverts et on affiche l'écran d'accès révoqué ; la file locale est conservée.
  Future<void> _recheckAccess() async {
    final user = _user;
    if (user == null || !mounted) return;
    try {
      final profile = await _repository.loadProfile(user.id);
      if (!mounted || user.id != _user?.id) return;
      if (profile != null && profile.hasValidAccess) {
        unawaited(_startWorker(user.id));
        return;
      }
      unawaited(_stopWorker());
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => _profileFuture = Future<NfcProfile?>.value(profile));
    } catch (_) {
      // Réseau indisponible : l'accès en cache reste valable jusqu'au prochain contrôle réussi.
    }
  }

  void _onAuthChanged(AuthState state) {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      if (!mounted) return;
      setState(() => _passwordSetup = true);
      return;
    }
    final nextUser = state.session?.user ?? _repository.currentUser;
    if (nextUser?.id == _user?.id) return;
    if (!mounted) return;
    setState(() {
      _user = nextUser;
      _profileFuture = _futureFor(nextUser);
    });
  }

  void _retryProfile() {
    final user = _user;
    if (user == null) return;
    setState(() => _profileFuture = _repository.loadProfile(user.id));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accessTimer?.cancel();
    _authSubscription?.cancel();
    unawaited(_stopWorker());
    unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return LoginScreen(repository: _repository);

    if (_passwordSetup) {
      return PasswordSetupScreen(repository: _repository);
    }

    final future = _profileFuture;
    if (future == null) return LoginScreen(repository: _repository);

    return FutureBuilder<NfcProfile?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ProfileLoadingScreen();
        }
        if (snapshot.hasError) {
          return AccessRevokedScreen(
            title: 'Profil indisponible',
            message:
                'Impossible de charger votre profil dans le schéma nfc. '
                'Réessayez lorsque la connexion sera disponible.',
            icon: Icons.cloud_sync_rounded,
            onRetry: _retryProfile,
            onSignOut: _repository.signOut,
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return AccessRevokedScreen(
            title: 'Accès non configuré',
            message:
                'Aucun profil IziCard n’est associé à ce compte. Contactez '
                'votre administrateur pour demander un accès.',
            icon: Icons.person_off_rounded,
            onSignOut: _repository.signOut,
          );
        }
        if (!profile.hasValidAccess) {
          return AccessRevokedScreen(
            title: 'Accès suspendu ou expiré',
            message:
                'Votre accès IziCard n’est plus actif. Contactez votre '
                'administrateur si vous pensez qu’il s’agit d’une erreur.',
            icon: Icons.lock_clock_rounded,
            onSignOut: _repository.signOut,
          );
        }

        return AppRouter.homeFor(
          profile: profile,
          repository: _repository,
        );
      },
    );
  }
}

class _ProfileLoadingScreen extends StatelessWidget {
  const _ProfileLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text('Chargement de votre espace sécurisé…'),
            ],
          ),
        ),
      ),
    );
  }
}
