class NfcTagRecord {
  const NfcTagRecord({
    required this.id,
    required this.batchId,
    required this.sequence,
    required this.publicId,
    required this.dataType,
    required this.payload,
    required this.fields,
    required this.status,
    this.uid,
    this.locked = false,
    this.attempts = 0,
    this.lastError,
    this.writtenAt,
  });

  final String id;
  final String batchId;
  final int sequence;
  final String publicId;
  final String dataType;
  final String payload;
  final Map<String, dynamic> fields;
  final String status;
  final String? uid;
  final bool locked;
  final int attempts;
  final String? lastError;
  final String? writtenAt;

  NfcTagRecord copyWith({String? status, String? uid, bool? locked, String? lastError, bool clearError = false}) => NfcTagRecord(
        id: id,
        batchId: batchId,
        sequence: sequence,
        publicId: publicId,
        dataType: dataType,
        payload: payload,
        fields: fields,
        status: status ?? this.status,
        uid: uid ?? this.uid,
        locked: locked ?? this.locked,
        attempts: attempts + 1,
        lastError: clearError ? null : lastError ?? this.lastError,
        writtenAt: writtenAt,
      );

  bool get isWritable => !locked && status != 'verified' && status != 'void';

  factory NfcTagRecord.fromMap(Map<String, dynamic> map) => NfcTagRecord(
        id: map['id'].toString(),
        batchId: map['batch_id'].toString(),
        sequence: map['seq'] is int ? map['seq'] as int : int.tryParse('${map['seq']}') ?? 0,
        publicId: map['public_id']?.toString() ?? '',
        dataType: map['data_type']?.toString() ?? 'text',
        payload: map['payload']?.toString() ?? '',
        fields: map['fields'] is Map ? Map<String, dynamic>.from(map['fields'] as Map) : const {},
        status: map['status']?.toString() ?? 'pending',
        uid: map['uid']?.toString(),
        locked: map['locked'] == true,
        attempts: map['attempts'] is int ? map['attempts'] as int : int.tryParse('${map['attempts']}') ?? 0,
        lastError: map['last_error']?.toString(),
        writtenAt: map['written_at']?.toString(),
      );
}
