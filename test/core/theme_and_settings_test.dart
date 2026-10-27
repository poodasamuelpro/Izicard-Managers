import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/settings/app_settings.dart';
import '../../lib/core/theme/izicard_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Thèmes IziCard', () {
    test('définit des palettes claires et sombres distinctes', () {
      expect(IzicardTheme.light.brightness, Brightness.light);
      expect(IzicardTheme.dark.brightness, Brightness.dark);
      expect(
        IzicardTheme.light.scaffoldBackgroundColor,
        isNot(IzicardTheme.dark.scaffoldBackgroundColor),
      );
      expect(
        IzicardTheme.light.colorScheme.onSurface,
        isNot(IzicardTheme.dark.colorScheme.onSurface),
      );
    });
  });

  group('AppSettingsStore', () {
    test(
      'utilise le thème système par défaut et restaure le choix sombre',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = AppSettingsStore.instance;

        await store.load();
        expect(store.value.themeMode, ThemeMode.system);

        await store.update(store.value.copyWith(themeMode: ThemeMode.dark));
        await store.load();
        expect(store.value.themeMode, ThemeMode.dark);
        expect(store.value.keepAwake, isTrue);
      },
    );
  });
}
