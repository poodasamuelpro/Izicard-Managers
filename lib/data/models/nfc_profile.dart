enum NfcRole {
  admin,
  client;

  static NfcRole parse(Object? value) {
    return switch (value?.toString()) {
      'admin' => NfcRole.admin,
      'client' => NfcRole.client,
      _ => throw FormatException('Rôle NFC inconnu.'),
    };
  }

  String get label => this == NfcRole.admin ? 'Administrateur' : 'Client';
}

class NfcProfile {
  const NfcProfile({
    required this.userId,
    required this.role,
    required this.active,
    this.clientId,
    this.fullName,
    this.accessExpiresAt,
    this.clientActive = true,
    this.clientAccessExpiresAt,
    this.canCreateBatches = false,
  });

  final String userId;
  final NfcRole role;
  final String? clientId;
  final String? fullName;
  final bool active;
  final DateTime? accessExpiresAt;
  final bool clientActive;
  final DateTime? clientAccessExpiresAt;
  final bool canCreateBatches;

  bool get hasValidAccess {
    final now = DateTime.now().toUtc();
    if (!active ||
        (accessExpiresAt != null && !accessExpiresAt!.isAfter(now))) {
      return false;
    }
    if (role == NfcRole.client) {
      if (clientId == null || !clientActive) return false;
      if (clientAccessExpiresAt != null &&
          !clientAccessExpiresAt!.isAfter(now)) {
        return false;
      }
    }
    return true;
  }

  String get displayName =>
      (fullName?.trim().isNotEmpty ?? false) ? fullName!.trim() : 'Utilisateur';

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  factory NfcProfile.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? client,
  }) {
    final role = NfcRole.parse(map['role']);
    final clientId = map['client_id']?.toString();
    if (role == NfcRole.client && (clientId == null || clientId.isEmpty)) {
      throw const FormatException('Profil client sans client associé.');
    }
    return NfcProfile(
      userId: map['user_id']?.toString() ?? '',
      role: role,
      clientId: clientId,
      fullName: map['full_name']?.toString(),
      active: map['active'] == true,
      accessExpiresAt: _date(map['access_expires_at']),
      clientActive: role == NfcRole.admin ? true : client?['active'] == true,
      clientAccessExpiresAt: _date(client?['access_expires_at']),
      canCreateBatches: client?['can_create_batches'] == true,
    );
  }
}
