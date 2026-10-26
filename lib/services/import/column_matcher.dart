import '../../core/utils/text_normalizer.dart';
import '../../data/models/card_format.dart';

class ColumnMatcher {
  const ColumnMatcher._();

  static const Map<String, List<String>> _specialAliases = {
    '_type': ['_type', 'type de donnee', 'type de donnée', 'data type'],
    '_payload': ['_payload', 'payload', 'donnee brute', 'donnée brute', 'contenu brut'],
  };

  static Map<int, String?> suggest(List<String> headers, CardFormat format) {
    final aliases = <String, String>{};
    for (final field in format.fields) {
      aliases[TextNormalizer.normalize(field.key)] = field.key;
      aliases[TextNormalizer.normalize(field.label)] = field.key;
      for (final alias in field.aliases) {
        aliases[TextNormalizer.normalize(alias)] = field.key;
      }
    }
    for (final entry in _specialAliases.entries) {
      for (final alias in entry.value) {
        aliases[TextNormalizer.normalize(alias)] = entry.key;
      }
    }

    final result = <int, String?>{};
    final used = <String>{};
    for (var index = 0; index < headers.length; index++) {
      final candidate = aliases[TextNormalizer.normalize(headers[index])];
      if (candidate != null && used.add(candidate)) {
        result[index] = candidate;
      } else {
        result[index] = null;
      }
    }
    return result;
  }

  static List<String> destinations(CardFormat format) => [
        ...format.fields.map((field) => field.key),
        '_type',
        '_payload',
      ];
}
