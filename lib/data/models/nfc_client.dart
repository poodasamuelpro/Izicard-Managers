class NfcClient {
  const NfcClient({
    required this.id,
    required this.name,
    required this.active,
    this.contactName,
    this.email,
    this.phone,
    this.accessExpiresAt,
    this.canCreateBatches = false,
  });

  final String id;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final bool active;
  final DateTime? accessExpiresAt;
  final bool canCreateBatches;

  factory NfcClient.fromMap(Map<String, dynamic> map) => NfcClient(
        id: map['id'].toString(),
        name: map['name']?.toString() ?? 'Client sans nom',
        contactName: map['contact_name']?.toString(),
        email: map['email']?.toString(),
        phone: map['phone']?.toString(),
        active: map['active'] == true,
        accessExpiresAt: _parseDate(map['access_expires_at']),
        canCreateBatches: map['can_create_batches'] == true,
      );

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  bool get isExpired =>
      accessExpiresAt != null && !accessExpiresAt!.isAfter(DateTime.now());

  String get accessLabel => !active
      ? 'Suspendu'
      : isExpired
          ? 'Expiré'
          : 'Actif';
}
