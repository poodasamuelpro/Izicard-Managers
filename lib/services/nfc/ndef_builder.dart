import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';

class NdefPayloadBuilder {
  const NdefPayloadBuilder._();

  static NdefMessage build({
    required String dataType,
    required String payload,
  }) {
    final lower = dataType.toLowerCase();
    if (lower == 'url' ||
        payload.startsWith('http://') ||
        payload.startsWith('https://') ||
        payload.startsWith('tel:') ||
        payload.startsWith('sms:') ||
        payload.startsWith('mailto:') ||
        payload.startsWith('geo:')) {
      return NdefMessage(
        records: [
          _wellKnown('U', Uint8List.fromList([0, ...utf8.encode(payload)])),
        ],
      );
    }
    if (lower == 'contact' || payload.startsWith('BEGIN:VCARD')) {
      return NdefMessage(records: [_mime('text/vcard', payload)]);
    }
    return NdefMessage(
      records: [
        _wellKnown(
          'T',
          Uint8List.fromList([
            2,
            ...utf8.encode('fr'),
            ...utf8.encode(payload),
          ]),
        ),
      ],
    );
  }

  static NdefRecord _wellKnown(String type, Uint8List payload) => NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList(ascii.encode(type)),
    identifier: Uint8List(0),
    payload: payload,
  );

  static NdefRecord _mime(String type, String payload) => NdefRecord(
    typeNameFormat: TypeNameFormat.media,
    type: Uint8List.fromList(ascii.encode(type)),
    identifier: Uint8List(0),
    payload: Uint8List.fromList(utf8.encode(payload)),
  );
}
