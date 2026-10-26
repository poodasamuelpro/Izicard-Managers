import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/settings/app_settings.dart';

/// Retour sonore / vibration et écran maintenu allumé, selon les réglages.
class FeedbackService {
  const FeedbackService._();

  static Future<void> signal({required bool success}) async {
    final settings = AppSettingsStore.instance.value;
    if (settings.vibration) {
      if (success) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 140));
        await HapticFeedback.heavyImpact();
      }
    }
    if (settings.sound) {
      await SystemSound.play(success ? SystemSoundType.click : SystemSoundType.alert);
    }
  }

  static Future<void> keepAwake(bool enable) async {
    try {
      if (enable && AppSettingsStore.instance.value.keepAwake) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Non bloquant : l'écriture continue même si l'écran peut s'éteindre.
    }
  }
}
