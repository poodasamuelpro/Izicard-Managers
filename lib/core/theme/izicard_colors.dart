import 'package:flutter/material.dart';

class IzicardColors {
  const IzicardColors._();

  static const cyan = Color(0xFF01A3CA);
  static const blue = Color(0xFF0299E2);
  static const ink = Color(0xFF12324A);
  static const muted = Color(0xFF617586);
  static const canvas = Color(0xFFF5F9FB);
  static const paleCyan = Color(0xFFE6F7FB);
  static const border = Color(0xFFE2EBF0);
  static const success = Color(0xFF21845A);
  static const warning = Color(0xFFB76A12);
  static const error = Color(0xFFB42318);

  // États d'une carte (texte blanc lisible) — identiques au web.
  static const statusPending = Color(0xFFC2410C);
  static const statusWritten = Color(0xFF006A91);
  static const statusVerified = Color(0xFF15803D);
  static const statusError = Color(0xFFB91C1C);
  static const statusVoid = Color(0xFF617586);

  static Color forTagStatus(String status) => switch (status) {
    'pending' => statusPending,
    'written' => statusWritten,
    'verified' => statusVerified,
    'error' => statusError,
    _ => statusVoid,
  };

  static String labelForTagStatus(String status) => switch (status) {
    'pending' => 'À écrire',
    'written' => 'Écrit',
    'verified' => 'Vérifié',
    'error' => 'Erreur',
    'void' => 'Annulé',
    _ => status,
  };
}

/// Couleurs sémantiques lisibles sur le fond courant (textes, icônes, filets).
/// Les fonds pleins à texte blanc gardent `IzicardColors.status*` ; tout ce qui est
/// posé directement sur la surface passe par ici pour rester contrasté en thème sombre.
class IzicardInk {
  const IzicardInk._(this.dark);
  factory IzicardInk.of(BuildContext context) =>
      IzicardInk._(Theme.of(context).brightness == Brightness.dark);

  final bool dark;

  Color get pending =>
      dark ? const Color(0xFFFFB27A) : IzicardColors.statusPending;
  Color get written =>
      dark ? const Color(0xFF78C8FF) : IzicardColors.statusWritten;
  Color get verified =>
      dark ? const Color(0xFF6AD99A) : IzicardColors.statusVerified;
  Color get error => dark ? const Color(0xFFFFB4AB) : IzicardColors.statusError;
  Color get voided => dark ? const Color(0xFFB7C7D1) : IzicardColors.statusVoid;

  Color forStatus(String status) => switch (status) {
    'pending' => pending,
    'written' => written,
    'verified' => verified,
    'error' => error,
    _ => voided,
  };

  /// Dégradé des bandeaux d'en-tête (texte blanc toujours lisible dessus).
  List<Color> get hero =>
      dark
          ? const [Color(0xFF0B6A82), Color(0xFF0B5C8C)]
          : const [Color(0xFF007F9E), Color(0xFF006EAA)];
}

extension IzicardContext on BuildContext {
  IzicardInk get ink => IzicardInk.of(this);
}
