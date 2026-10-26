import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/izicard_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/remote/tags_remote.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/sync_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.profile, required this.repository, this.email = ''});
  final NfcProfile profile;
  final AuthRepository repository;
  final String email;

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(repository: repository),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe modifié.')));
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    var pending = 0;
    final database = AppDatabase();
    try {
      final client = Supabase.instance.client;
      pending = await SyncRepository(
        database: database,
        remote: TagsRemote(client),
        userId: client.auth.currentUser?.id ?? '',
      ).pendingCount();
    } catch (_) {
      pending = 0;
    } finally {
      await database.close();
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Se déconnecter ?'),
        content: Text(pending > 0
            ? '$pending résultat(s) d’écriture ne sont pas encore synchronisés. Ils restent sur cet appareil '
                'et seront envoyés à votre prochaine connexion avec ce compte.'
            : 'Votre session sera fermée sur cet appareil.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Déconnexion')),
        ],
      ),
    );
    if (confirmed != true) return;
    navigator.popUntil((route) => route.isFirst);
    await repository.signOut();
  }

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
              Text('Compte', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.key_rounded),
                    title: const Text('Changer le mot de passe'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _changePassword(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: IzicardColors.statusError),
                    title: const Text('Se déconnecter', style: TextStyle(color: IzicardColors.statusError)),
                    onTap: () => _signOut(context),
                  ),
                  const Divider(height: 1),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) => ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Version de l’application'),
                      subtitle: Text(snapshot.hasData
                          ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                          : snapshot.hasError
                              ? 'Indisponible'
                              : '…'),
                    ),
                  ),
                ]),
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


class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.repository});
  final AuthRepository repository;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updatePassword(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Modification impossible. Vérifiez votre connexion puis réessayez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  helperText: '8 caractères minimum',
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Afficher' : 'Masquer',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) => (value ?? '').length < 8 ? 'Au moins 8 caractères.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirm,
                obscureText: _hidden,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                validator: (value) => value != _password.text ? 'Les mots de passe ne correspondent pas.' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: IzicardColors.statusError)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
        ],
      );
}
