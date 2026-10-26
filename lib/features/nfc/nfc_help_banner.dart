import 'package:app_settings/app_settings.dart' as os;
import 'package:flutter/material.dart';

import '../../core/theme/izicard_colors.dart';
import '../../services/nfc/nfc_service.dart';

/// Bandeau d'aide quand le NFC est désactivé (ou absent). Se met à jour au retour des réglages Android.
class NfcHelpBanner extends StatefulWidget {
  const NfcHelpBanner({super.key, this.onChanged});

  /// Appelé à chaque contrôle avec l'état courant (vrai = NFC prêt).
  final ValueChanged<bool>? onChanged;

  @override
  State<NfcHelpBanner> createState() => _NfcHelpBannerState();
}

class _NfcHelpBannerState extends State<NfcHelpBanner> with WidgetsBindingObserver {
  bool? _available;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    bool available;
    try {
      available = await NfcService.isAvailable();
    } catch (_) {
      available = false;
    }
    _checking = false;
    if (!mounted) return;
    setState(() => _available = available);
    widget.onChanged?.call(available);
  }

  Future<void> _openSettings() async {
    try {
      await os.AppSettings.openAppSettings(type: os.AppSettingsType.nfc);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ouvrez Réglages Android > Appareils connectés > NFC.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_available != false) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFFFF3E8),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.nfc_rounded, color: IzicardColors.statusPending),
            SizedBox(width: 10),
            Expanded(
              child: Text('NFC indisponible ou désactivé',
                  style: TextStyle(fontWeight: FontWeight.w800, color: IzicardColors.statusPending)),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Pour encoder ou lire une carte, activez le NFC : Réglages Android > Appareils connectés > '
            'Préférences de connexion > NFC. Si l’option n’existe pas, ce téléphone n’a pas de lecteur NFC.',
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Ouvrir les réglages NFC'),
            ),
            OutlinedButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Vérifier à nouveau'),
            ),
          ]),
        ]),
      ),
    );
  }
}
