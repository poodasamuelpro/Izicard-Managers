import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';
import '../local/app_database.dart';
import '../models/nfc_profile.dart';

class AuthRepository {
  AuthRepository(this._client, {AppDatabase? database}) : _database = database;

  final SupabaseClient _client;
  final AppDatabase? _database;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Lit le profil en ligne puis le met en cache pour les démarrages hors ligne.
  Future<NfcProfile?> loadProfile(String userId) async {
    try {
      final profile = await _loadRemoteProfile(userId);
      if (profile != null) {
        try {
          await _database?.cacheProfile(
            userId: userId,
            payload: profile.$1,
          );
        } catch (_) {
          // Le cache est un secours : il ne doit pas bloquer l’accès en ligne.
        }
      } else {
        await _database?.deleteCachedProfile(userId);
      }
      return profile?.$2;
    } catch (_) {
      return _loadCachedProfile(userId);
    }
  }

  Future<(Map<String, dynamic>, NfcProfile)?> _loadRemoteProfile(
    String userId,
  ) async {
    final profileRow = await _client
        .schema(AppConstants.nfcSchema)
        .from('nfc_profiles')
        .select(
          'user_id, role, client_id, full_name, active, access_expires_at',
        )
        .eq('user_id', userId)
        .maybeSingle();

    if (profileRow == null) return null;

    final row = Map<String, dynamic>.from(profileRow);
    Map<String, dynamic>? clientRow;
    final role = NfcRole.parse(row['role']);
    final clientId = row['client_id']?.toString();

    if (role == NfcRole.client && clientId != null) {
      final result = await _client
          .schema(AppConstants.nfcSchema)
          .from('nfc_clients')
          .select('active, access_expires_at, can_create_batches')
          .eq('id', clientId)
          .maybeSingle();
      if (result != null) clientRow = Map<String, dynamic>.from(result);
    }

    return (
      <String, dynamic>{'profile': row, 'client': clientRow},
      NfcProfile.fromMap(row, client: clientRow),
    );
  }

  Future<NfcProfile?> _loadCachedProfile(String userId) async {
    final cached = await _database?.readCachedProfile(userId);
    if (cached == null) return null;
    final profile = cached['profile'];
    final client = cached['client'];
    if (profile is! Map) return null;
    return NfcProfile.fromMap(
      Map<String, dynamic>.from(profile),
      client: client is Map ? Map<String, dynamic>.from(client) : null,
    );
  }

  Future<void> requestPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> verifyRecoveryCode({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  /// La file locale n’est pas supprimée : elle doit survivre au hors-ligne,
  /// au redémarrage et à une reconnexion avant sa synchronisation.
  Future<void> signOut() => _client.auth.signOut();
}
