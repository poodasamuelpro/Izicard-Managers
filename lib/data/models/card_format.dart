class CardField {
  const CardField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.aliases = const [],
    this.digitsOnly = false,
  });

  final String key;
  final String label;
  final String type;
  final bool required;
  final List<String> aliases;
  final bool digitsOnly;

  factory CardField.fromMap(Map<String, dynamic> map) => CardField(
    key: map['key']?.toString() ?? '',
    label: map['label']?.toString() ?? map['key']?.toString() ?? '',
    type: map['type']?.toString() ?? 'text',
    required: map['required'] == true,
    aliases:
        (map['aliases'] is List)
            ? (map['aliases'] as List).map((value) => value.toString()).toList()
            : const [],
    digitsOnly: map['digits_only'] == true,
  );
}

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
    this.fields = const [],
    this.rules = const {},
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
  final List<CardField> fields;
  final Map<String, dynamic> rules;

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
    fields:
        map['field_schema'] is List
            ? (map['field_schema'] as List)
                .whereType<Map>()
                .map(
                  (value) =>
                      CardField.fromMap(Map<String, dynamic>.from(value)),
                )
                .where((field) => field.key.isNotEmpty)
                .toList()
            : const [],
    rules:
        map['rules'] is Map
            ? Map<String, dynamic>.from(map['rules'] as Map)
            : const {},
  );

  static int _asInt(Object? value, int fallback) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}
