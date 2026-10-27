import 'card_format.dart';

class NfcBatch {
  const NfcBatch({
    required this.id,
    required this.clientId,
    required this.name,
    required this.status,
    required this.quantity,
    this.total = 0,
    this.pending = 0,
    this.written = 0,
    this.verified = 0,
    this.errors = 0,
    this.voided = 0,
  });

  final String id;
  final String clientId;
  final String name;
  final String status;
  final int quantity;
  final int total;
  final int pending;
  final int written;
  final int verified;
  final int errors;
  final int voided;

  double get progress => total == 0 ? 0 : verified / total;

  String get statusLabel => switch (status) {
    'draft' => 'Brouillon',
    'ready' => 'Prêt',
    'in_progress' => 'En cours',
    'completed' => 'Terminé',
    'archived' => 'Archivé',
    _ => status,
  };

  factory NfcBatch.fromStats(Map<String, dynamic> map) => NfcBatch(
    id: (map['batch_id'] ?? map['id']).toString(),
    clientId: map['client_id']?.toString() ?? '',
    name: map['name']?.toString() ?? 'Dossier sans nom',
    status: map['status']?.toString() ?? 'draft',
    quantity: _asInt(map['quantity']),
    total: _asInt(map['total']),
    pending: _asInt(map['pending']),
    written: _asInt(map['written']),
    verified: _asInt(map['verified']),
    errors: _asInt(map['error']),
    voided: _asInt(map['void']),
  );

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}

class BatchImportContext {
  const BatchImportContext({
    required this.id,
    required this.name,
    required this.dataType,
    required this.format,
    required this.settings,
    required this.status,
  });

  final String id;
  final String name;
  final String dataType;
  final CardFormat format;
  final Map<String, dynamic> settings;
  final String status;
}
