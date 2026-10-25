class CardFormat {
  const CardFormat({
    required this.id,
    required this.code,
    required this.label,
    required this.chip,
    required this.capacityBytes,
    required this.defaultDataType,
    required this.active,
    this.product,
    this.payloadTemplate,
    this.idPrefix = '',
    this.idLength = 10,
    this.lockDefault = false,
  });

  final String id;
  final String code;
  final String label;
  final String chip;
  final int capacityBytes;
  final String defaultDataType;
  final bool active;
  final String? product;
  final String? payloadTemplate;
  final String idPrefix;
  final int idLength;
  final bool lockDefault;

  factory CardFormat.fromMap(Map<String, dynamic> map) => CardFormat(
        id: map['id'].toString(),
        code: map['code']?.toString() ?? '',
        label: map['label']?.toString() ?? 'Format sans nom',
        product: map['product']?.toString(),
        chip: map['chip']?.toString() ?? 'NTAG213',
        capacityBytes: _asInt(map['capacity_bytes'], 144),
        defaultDataType: map['default_data_type']?.toString() ?? 'url',
        payloadTemplate: map['payload_template']?.toString(),
        idPrefix: map['id_prefix']?.toString() ?? '',
        idLength: _asInt(map['id_length'], 10),
        lockDefault: map['lock_default'] == true,
        active: map['active'] == true,
      );

  static int _asInt(Object? value, int fallback) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}
