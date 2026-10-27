import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';

import '../lib/services/nfc/ndef_builder.dart';

void main() {
  test(
    'construit un enregistrement URI NDEF avec le préfixe sans identifiant',
    () {
      final message = NdefPayloadBuilder.build(
        dataType: 'url',
        payload: 'https://izicard.example/card/123',
      );

      expect(message.records, hasLength(1));
      final record = message.records.single;
      expect(record.typeNameFormat, TypeNameFormat.wellKnown);
      expect(ascii.decode(record.type), 'U');
      expect(record.payload.first, 0);
      expect(
        utf8.decode(record.payload.sublist(1)),
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
}
