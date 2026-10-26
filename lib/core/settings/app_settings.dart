import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages locaux, propres à l'appareil.
@immutable
class AppSettings {
  const AppSettings({
    this.sound = true,
    this.vibration = true,
    this.autoAdvance = true,
    this.lockByDefault = false,
    this.keepAwake = true,
  });

  final bool sound;
  final bool vibration;
  final bool autoAdvance;

  /// Jamais activé par défaut : le verrouillage est définitif.
  final bool lockByDefault;
  final bool keepAwake;

  AppSettings copyWith({
    bool? sound,
    bool? vibration,
    bool? autoAdvance,
    bool? lockByDefault,
    bool? keepAwake,
  }) =>
      AppSettings(
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        autoAdvance: autoAdvance ?? this.autoAdvance,
        lockByDefault: lockByDefault ?? this.lockByDefault,
        keepAwake: keepAwake ?? this.keepAwake,
      );
}

class AppSettingsStore {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  final ValueNotifier<AppSettings> notifier = ValueNotifier(const AppSettings());
  AppSettings get value => notifier.value;

  static const _sound = 'settings.sound';
  static const _vibration = 'settings.vibration';
  static const _auto = 'settings.autoAdvance';
  static const _lock = 'settings.lockByDefault';
  static const _awake = 'settings.keepAwake';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      notifier.value = AppSettings(
        sound: prefs.getBool(_sound) ?? true,
        vibration: prefs.getBool(_vibration) ?? true,
        autoAdvance: prefs.getBool(_auto) ?? true,
        lockByDefault: prefs.getBool(_lock) ?? false,
        keepAwake: prefs.getBool(_awake) ?? true,
      );
    } catch (_) {
      notifier.value = const AppSettings();
    }
  }

  Future<void> update(AppSettings next) async {
    notifier.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sound, next.sound);
      await prefs.setBool(_vibration, next.vibration);
      await prefs.setBool(_auto, next.autoAdvance);
      await prefs.setBool(_lock, next.lockByDefault);
      await prefs.setBool(_awake, next.keepAwake);
    } catch (_) {
      // Le réglage reste actif pour la session même si le stockage échoue.
    }
  }
}
