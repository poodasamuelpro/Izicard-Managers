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
      );
}
