import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/home/home_screen.dart';

class IzicardApp extends StatelessWidget {
  const IzicardApp({super.key, this.configurationError = false});

  final bool configurationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IziCard NFC',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF01A3CA),
          primary: const Color(0xFF01A3CA),
          secondary: const Color(0xFF0299E2),
        ),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
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
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Configuration Supabase manquante. Lancez l’application avec '
            'SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = AuthRepository(Supabase.instance.client);
    return StreamBuilder<AuthState>(
      stream: repository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return repository.currentUser == null
            ? LoginScreen(repository: repository)
            : HomeScreen(repository: repository);
      },
    );
  }
}

class OtpRoute extends StatelessWidget {
  const OtpRoute({super.key, required this.email, required this.repository});

  final String email;
  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return OtpScreen(email: email, repository: repository);
  }
}
