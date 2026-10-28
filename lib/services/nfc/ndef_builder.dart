import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';

class NdefPayloadBuilder {
  const NdefPayloadBuilder._();

  /// Abréviations d'URI définies par la norme NFC Forum (code → préfixe).
  static const uriPrefixes = <String>[
    '',
    'http://www.',
    'https://www.',
    'http://',
    'https://',
    'tel:',
    'mailto:',
  ];

  /// Encode une URI avec l'abréviation la plus longue possible : gagne jusqu'à 11 octets,
  /// précieux sur une NTAG213 (144 octets).
  static Uint8List _uriPayload(String uri) {
    var code = 0;
    var best = 0;
    for (var i = 1; i < uriPrefixes.length; i++) {
      final prefix = uriPrefixes[i];
      if (uri.startsWith(prefix) && prefix.length > best) {
        code = i;
        best = prefix.length;
      }
    }
    return Uint8List.fromList([code, ...utf8.encode(uri.substring(best))]);
  }

  /// Texte complet d'un enregistrement URI (préfixe abrégé développé).
  static String decodeUri(Uint8List payload) {
    if (payload.isEmpty) return '';
    final code = payload.first;
    final prefix = code < uriPrefixes.length ? uriPrefixes[code] : '';
    return '$prefix${utf8.decode(payload.sublist(1), allowMalformed: true)}';
  }

  /// Texte d'un enregistrement Texte (octet de langue ignoré).
  static String decodeText(Uint8List payload) {
    if (payload.isEmpty) return '';
    final start = 1 + (payload.first & 0x3f);
    return start <= payload.length
        ? utf8.decode(payload.sublist(start), allowMalformed: true)
        : '';
  }

  static NdefMessage build({
    required String dataType,
    required String payload,
  }) {
    final lower = dataType.toLowerCase();
    var value = payload.trim();
    // Un numéro ou un e-mail sans schéma reste une action utile (appel / e-mail) sur le téléphone.
    if (lower == 'phone' && !value.startsWith('tel:')) {
      value = 'tel:$value';
    } else if (lower == 'email' && !value.startsWith('mailto:')) {
      value = 'mailto:$value';
    }
    if (value.startsWith('tel:')) {
      value = 'tel:${value.substring(4).replaceAll(RegExp(r'[\s().-]'), '')}';
    }
    if (lower == 'url' ||
        lower == 'phone' ||
        lower == 'email' ||
        value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('tel:') ||
        value.startsWith('sms:') ||
        value.startsWith('mailto:') ||
        value.startsWith('geo:')) {
      return NdefMessage(records: [_wellKnown('U', _uriPayload(value))]);
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
