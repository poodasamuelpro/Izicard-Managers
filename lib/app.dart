import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/izicard_theme.dart';
import 'data/local/app_database.dart';
import 'data/models/nfc_profile.dart';
import 'data/repositories/auth_repository.dart';
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

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _repository;
  late final AppDatabase _database;
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  Future<NfcProfile?>? _profileFuture;
  bool _passwordSetup = false;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _repository = AuthRepository(Supabase.instance.client, database: _database);
    _user = _repository.currentUser;
    _profileFuture = _futureFor(_user);
    _authSubscription = _repository.authStateChanges.listen(_onAuthChanged);
  }

  Future<NfcProfile?>? _futureFor(User? user) =>
      user == null ? null : _repository.loadProfile(user.id);

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
    _authSubscription?.cancel();
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
