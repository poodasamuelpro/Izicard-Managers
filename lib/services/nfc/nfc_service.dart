import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'ndef_builder.dart';

class NfcReadResult {
  const NfcReadResult({required this.uid, required this.message, this.maxSize, this.cancelled = false});
  final String uid;
  final NdefMessage? message;
  final int? maxSize;
  final bool cancelled;
}

class NfcWriteResult {
  const NfcWriteResult({
    required this.uid,
    required this.verified,
    this.error,
    this.recordable = true,
    this.cancelled = false,
    this.locked = false,
  });
  final String uid;
  final bool verified;
  final String? error;

  /// Faux quand rien n'a été écrit (aucun tag, annulation, tag refusé) : rien à signaler à la base.
  final bool recordable;
  final bool cancelled;

  /// Vrai si le verrouillage définitif a réellement été appliqué.
  final bool locked;
}

class NfcService {
  const NfcService._();

  static Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  static Completer<NfcReadResult>? _activeRead;

  /// Attend un tag, le lit une seule fois et ferme toujours la session.
  /// L'attente est annulable et limitée dans le temps pour éviter un écran bloqué.
  static Future<NfcReadResult> readOnce({Duration timeout = const Duration(seconds: 60)}) async {
    if (!await isAvailable()) {
      throw const FormatException('NFC indisponible ou désactivé. Activez le NFC dans les réglages Android.');
    }
    final completer = Completer<NfcReadResult>();
    _activeRead = completer;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (tag) async {
          try {
            final ndef = Ndef.from(tag);
            final uid = _uid(tag);
            final message = await ndef?.read();
            if (!completer.isCompleted) {
              completer.complete(NfcReadResult(uid: uid, message: message, maxSize: ndef?.maxSize));
            }
          } catch (error) {
            if (!completer.isCompleted) completer.completeError(error);
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
        noPlatformSoundsAndroid: false,
      );
      return await completer.future.timeout(
        timeout,
        onTimeout: () async {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          throw TimeoutException('Aucun tag détecté dans le délai imparti.');
        },
      );
    } finally {
      if (identical(_activeRead, completer)) _activeRead = null;
    }
  }

  static Completer<NfcWriteResult>? _active;

  /// Annule proprement une lecture ou une écriture NFC en cours.
  static Future<void> cancel() async {
    final read = _activeRead;
    if (read != null && !read.isCompleted) {
      read.complete(const NfcReadResult(uid: '', message: null, cancelled: true));
    }
    final active = _active;
    if (active != null && !active.isCompleted) {
      active.complete(const NfcWriteResult(uid: '', verified: false, recordable: false, cancelled: true, error: 'Action annulée.'));
    }
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Aucune session à fermer.
    }
  }

  /// Compare deux messages NDEF enregistrement par enregistrement (type, format, contenu).
  static bool sameMessage(NdefMessage a, NdefMessage b) {
    if (a.records.length != b.records.length) return false;
    for (var i = 0; i < a.records.length; i++) {
      final x = a.records[i];
      final y = b.records[i];
      if (x.typeNameFormat != y.typeNameFormat) return false;
      if (!_sameBytes(x.type, y.type) || !_sameBytes(x.payload, y.payload)) return false;
    }
    return true;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Attend un tag, écrit, RELIT et compare, puis verrouille seulement si demandé et si la relecture est bonne.
  /// [guard] peut refuser un tag AVANT toute écriture (ex. UID déjà associé à une autre carte).
  static Future<NfcWriteResult> writeOnce({
    required String dataType,
    required String payload,
    required bool lockAfterWrite,
    Future<String?> Function(String uid)? guard,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!await isAvailable()) {
      return const NfcWriteResult(
        uid: '',
        verified: false,
        recordable: false,
        error: 'NFC indisponible ou désactivé. Activez le NFC dans les réglages Android.',
      );
    }
    final expected = NdefPayloadBuilder.build(dataType: dataType, payload: payload);
    final completer = Completer<NfcWriteResult>();
    _active = completer;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693, NfcPollingOption.iso18092},
        onDiscovered: (tag) async {
          final uid = _uid(tag);
          try {
            final refusal = guard == null ? null : await guard(uid);
            if (refusal != null) {
              if (!completer.isCompleted) completer.complete(NfcWriteResult(uid: uid, verified: false, recordable: false, error: refusal));
              return;
            }
            final ndef = Ndef.from(tag);
            if (ndef == null) throw const FormatException('Ce tag ne prend pas en charge NDEF.');
            if (!ndef.isWritable) throw const FormatException('Ce tag n’est pas inscriptible (déjà verrouillé ?).');
            if (ndef.maxSize < expected.byteLength) {
              throw FormatException('Donnée trop volumineuse : ${expected.byteLength} octets pour ${ndef.maxSize}.');
            }
            await ndef.write(message: expected);
            final readBack = await ndef.read();
            if (readBack == null || !sameMessage(readBack, expected)) {
              throw const FormatException('La relecture du tag ne correspond pas à la donnée écrite.');
            }
            var locked = false;
            String? lockNote;
            if (lockAfterWrite) {
              try {
                await ndef.writeLock();
                locked = true;
              } catch (error) {
                lockNote = 'Écrit et vérifié, mais le verrouillage a échoué : ${_message(error)}';
              }
            }
            if (!completer.isCompleted) {
              completer.complete(NfcWriteResult(uid: uid, verified: true, locked: locked, error: lockNote));
            }
          } catch (error) {
            if (!completer.isCompleted) completer.complete(NfcWriteResult(uid: uid, verified: false, error: _message(error)));
          } finally {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
          }
        },
        noPlatformSoundsAndroid: false,
      );
      return await completer.future.timeout(timeout, onTimeout: () async {
        try {
          await NfcManager.instance.stopSession();
        } catch (_) {}
        return const NfcWriteResult(uid: '', verified: false, recordable: false, error: 'Aucun tag détecté (délai dépassé).');
      });
    } catch (error) {
      return NfcWriteResult(uid: '', verified: false, recordable: false, error: _message(error));
    } finally {
      if (identical(_active, completer)) _active = null;
    }
  }

  static String _uid(NfcTag tag) {
    final android = NfcTagAndroid.from(tag);
    if (android != null) return _hex(android.id);
    return 'INCONNU';
  }

  static String _hex(Uint8List bytes) => bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  static String _message(Object error) => error is FormatException ? error.message : error.toString().replaceFirst('Exception: ', '');
}
