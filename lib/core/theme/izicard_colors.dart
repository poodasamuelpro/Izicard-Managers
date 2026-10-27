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
