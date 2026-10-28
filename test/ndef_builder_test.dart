import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';

import '../lib/services/nfc/ndef_builder.dart';
import '../lib/services/nfc/nfc_service.dart';

void main() {
  test(
    'construit un enregistrement URI NDEF avec le préfixe abrégé https://',
    () {
      final message = NdefPayloadBuilder.build(
        dataType: 'url',
        payload: 'https://izicard.example/card/123',
      );

      expect(message.records, hasLength(1));
      final record = message.records.single;
      expect(record.typeNameFormat, TypeNameFormat.wellKnown);
      expect(ascii.decode(record.type), 'U');
      expect(record.payload.first, 4);
      expect(
        utf8.decode(record.payload.sublist(1)),
        'izicard.example/card/123',
      );
      expect(
        NdefPayloadBuilder.decodeUri(record.payload),
        'https://izicard.example/card/123',
      );
    },
  );

  test('construit un contact vCard en enregistrement MIME', () {
    final message = NdefPayloadBuilder.build(
      dataType: 'contact',
      payload: 'BEGIN:VCARD\\nVERSION:3.0\\nEND:VCARD',
    );

    final record = message.records.single;
    expect(record.typeNameFormat, TypeNameFormat.media);
    expect(ascii.decode(record.type), 'text/vcard');
    expect(
      utf8.decode(record.payload),
      'BEGIN:VCARD\\nVERSION:3.0\\nEND:VCARD',
    );
  });

  test('encode une donnée ordinaire comme texte UTF-8 français', () {
    final message = NdefPayloadBuilder.build(
      dataType: 'text',
      payload: 'Équipe IziCard',
    );

    final record = message.records.single;
    expect(record.typeNameFormat, TypeNameFormat.wellKnown);
    expect(ascii.decode(record.type), 'T');
    expect(record.payload.take(3).toList(), [2, 0x66, 0x72]);
    expect(utf8.decode(record.payload.sublist(3)), 'Équipe IziCard');
  });

  test('un numéro de téléphone devient un lien tel: sans espaces', () {
    final message = NdefPayloadBuilder.build(
      dataType: 'phone',
      payload: '+212 6 12 34 56 78',
    );
    final record = message.records.single;
    expect(ascii.decode(record.type), 'U');
    expect(record.payload.first, 5);
    expect(NdefPayloadBuilder.decodeUri(record.payload), 'tel:+212612345678');
  });

  test('une URI abrégée ou non est considérée comme identique', () {
    final abbreviated = NdefPayloadBuilder.build(
      dataType: 'url',
      payload: 'https://exemple.com/a',
    );
    final plain = NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList(ascii.encode('U')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([0, ...utf8.encode('https://exemple.com/a')]),
        ),
      ],
    );
    expect(NfcService.sameMessage(abbreviated, plain), isTrue);
  });

  test('un tag vierge (enregistrement vide) est vu comme vide', () {
    final blank = NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.empty,
          type: Uint8List(0),
          identifier: Uint8List(0),
          payload: Uint8List(0),
        ),
      ],
    );
    expect(NfcService.isBlank(blank), isTrue);
    expect(NfcService.isBlank(null), isTrue);
  });
}
