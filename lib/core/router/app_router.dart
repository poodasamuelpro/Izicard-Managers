import 'package:flutter/widgets.dart';

import '../../data/models/nfc_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../features/home/home_screen.dart';

class AppRouter {
  const AppRouter._();

  /// Route l’utilisateur connecté selon le rôle chargé depuis `nfc`.
  static Widget homeFor({
    required NfcProfile profile,
    required AuthRepository repository,
  }) {
    return switch (profile.role) {
      NfcRole.admin => AdminHomeScreen(profile: profile, repository: repository),
      NfcRole.client => ClientHomeScreen(profile: profile, repository: repository),
    };
  }
}
