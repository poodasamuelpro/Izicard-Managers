import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';
import '../models/nfc_profile.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Lit le profil métier dans le schéma `nfc` après authentification.
  /// L’absence de profil signifie aucun accès métier.
  Future<NfcProfile?> loadProfile(String userId) async {
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

    return NfcProfile.fromMap(row, client: clientRow);
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
