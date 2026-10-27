import 'package:flutter_test/flutter_test.dart';

import '../lib/services/nfc/ndef_builder.dart';
import '../lib/services/nfc/nfc_service.dart';

void main() {
  test('reconnaît deux payloads NDEF identiques après relecture', () {
    final expected = NdefPayloadBuilder.build(
      dataType: 'text',
      payload: 'IZI-001',
    );
    final readBack = NdefPayloadBuilder.build(
      dataType: 'text',
      payload: 'IZI-001',
    );

    expect(NfcService.sameMessage(readBack, expected), isTrue);
  });

  test('refuse un payload différent après relecture NFC', () {
    final expected = NdefPayloadBuilder.build(
      dataType: 'text',
      payload: 'IZI-001',
    );
    final readBack = NdefPayloadBuilder.build(
      dataType: 'text',
      payload: 'IZI-002',
    );

    expect(NfcService.sameMessage(readBack, expected), isFalse);
  });
}
