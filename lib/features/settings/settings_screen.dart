import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_profile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.profile, this.email = ''});
  final NfcProfile profile;
  final String email;

  @override
  Widget build(BuildContext context) {
    final store = AppSettingsStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: ValueListenableBuilder<AppSettings>(
          valueListenable: store.notifier,
          builder: (context, settings, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: IzicardColors.paleCyan,
                    child: Icon(Icons.person_outline_rounded, color: IzicardColors.cyan),
                  ),
                  title: Text(profile.displayName),
                  subtitle: Text('${profile.role.label}${email.isEmpty ? '' : ' · $email'}'),
                ),
              ),
              const SizedBox(height: 18),
              Text('Écriture NFC', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Ces réglages sont enregistrés sur cet appareil.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: IzicardColors.muted)),
              const SizedBox(height: 8),
              Card(
                child: Column(children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: const Text('Son'),
                    subtitle: const Text('Bip à chaque succès ou erreur.'),
                    value: settings.sound,
                    onChanged: (value) => store.update(settings.copyWith(sound: value)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.vibration_rounded),
                    title: const Text('Vibration'),
                    subtitle: const Text('Retour tactile à chaque résultat.'),
                    value: settings.vibration,
                    onChanged: (value) => store.update(settings.copyWith(vibration: value)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.skip_next_rounded),
                    title: const Text('Avancement automatique'),
                    subtitle: const Text('Passer à la carte suivante après une carte vérifiée.'),
                    value: settings.autoAdvance,
                    onChanged: (value) => store.update(settings.copyWith(autoAdvance: value)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.brightness_high_outlined),
                    title: const Text('Écran toujours allumé'),
                    subtitle: const Text('Pendant une série d’écriture.'),
                    value: settings.keepAwake,
                    onChanged: (value) => store.update(settings.copyWith(keepAwake: value)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Verrouillage par défaut'),
                    subtitle: const Text(
                      'Verrouille définitivement chaque tag vérifié. Irréversible : désactivé par défaut, '
                      'et une confirmation est demandée à chaque série.',
                    ),
                    value: settings.lockByDefault,
                    onChanged: (value) => store.update(settings.copyWith(lockByDefault: value)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
