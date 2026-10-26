import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'ndef_builder.dart';

class NfcReadResult {
  const NfcReadResult({required this.uid, required this.message, this.maxSize});
  final String uid;
  final NdefMessage? message;
  final int? maxSize;
}

class NfcWriteResult {
  const NfcWriteResult({required this.uid, required this.verified, this.error});
  final String uid;
  final bool verified;
  final String? error;
}

class NfcService {
  const NfcService._();

  static Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  static Future<NfcReadResult> readOnce() async {
    final completer = Completer<NfcReadResult>();
    await NfcManager.instance.startSession(
      pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          final uid = _uid(tag);
          final message = await ndef?.read();
          if (!completer.isCompleted) completer.complete(NfcReadResult(uid: uid, message: message, maxSize: ndef?.maxSize));
        } catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
      noPlatformSoundsAndroid: false,
    );
    return completer.future;
  }

  static Future<NfcWriteResult> writeOnce({required String dataType, required String payload, required bool lockAfterWrite}) async {
    final expected = NdefPayloadBuilder.build(dataType: dataType, payload: payload);
    final completer = Completer<NfcWriteResult>();
    await NfcManager.instance.startSession(
      pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
      onDiscovered: (tag) async {
        final uid = _uid(tag);
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) throw const FormatException('Ce tag ne prend pas en charge NDEF.');
          if (!ndef.isWritable) throw const FormatException('Ce tag n’est pas inscriptible.');
          if (ndef.maxSize < expected.byteLength) throw FormatException('Donnée trop volumineuse : ${expected.byteLength} octets pour ${ndef.maxSize}.');
          await ndef.write(message: expected);
          final readBack = await ndef.read();
          if (readBack == null || readBack != expected) throw const FormatException('La relecture du tag ne correspond pas à la donnée écrite.');
          if (lockAfterWrite) await ndef.writeLock();
          if (!completer.isCompleted) completer.complete(NfcWriteResult(uid: uid, verified: true));
        } catch (error) {
          if (!completer.isCompleted) completer.complete(NfcWriteResult(uid: uid, verified: false, error: _message(error)));
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
      noPlatformSoundsAndroid: false,
    );
    return completer.future;
  }

  static String _uid(NfcTag tag) {
    final android = NfcTagAndroid.from(tag);
    if (android != null) return _hex(android.id);
    return 'INCONNU';
  }

  static String _hex(Uint8List bytes) => bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  static String _message(Object error) => error is FormatException ? error.message : error.toString().replaceFirst('Exception: ', '');
}
