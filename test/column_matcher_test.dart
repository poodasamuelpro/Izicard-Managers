import 'package:flutter_test/flutter_test.dart';

import '../lib/data/models/card_format.dart';
import '../lib/services/import/column_matcher.dart';

void main() {
  const format = CardFormat(
    id: 'format-1',
    code: 'client',
    label: 'Client',
    chip: 'NTAG213',
    capacityBytes: 144,
    defaultDataType: 'text',
    active: true,
    fields: [
      CardField(
        key: 'serial',
        label: 'Numéro de série',
        aliases: ['serial no'],
      ),
      CardField(key: 'name', label: 'Nom du client'),
    ],
  );

  test(
    'suggère les colonnes par libellé/alias et reconnaît les colonnes spéciales',
    () {
      final mapping = ColumnMatcher.suggest([
        'NUMERO DE SERIE',
        'Nom du client',
        'type de donnée',
        'payload',
      ], format);

      expect(mapping, {0: 'serial', 1: 'name', 2: '_type', 3: '_payload'});
      expect(ColumnMatcher.destinations(format), [
        'serial',
        'name',
        '_type',
        '_payload',
      ]);
    },
  );

  test('ne mappe pas deux colonnes vers la même destination', () {
    final mapping = ColumnMatcher.suggest(['serial', 'serial no'], format);
    expect(mapping, {0: 'serial', 1: null});
  });
}
