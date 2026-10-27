import 'package:flutter/material.dart';

import '../../services/feedback/feedback_service.dart';
import '../../services/nfc/nfc_service.dart';
import '../nfc/nfc_help_banner.dart';

/// Écriture d'une seule carte, sans dossier ni client : on saisit la donnée et on écrit.
/// Cette écriture n'est PAS enregistrée dans la base (aucune carte, aucun historique).
class QuickWriteScreen extends StatefulWidget {
  const QuickWriteScreen({super.key});

  @override
  State<QuickWriteScreen> createState() => _QuickWriteScreenState();
}

class _QuickWriteScreenState extends State<QuickWriteScreen> {
  static const _types = <String, String>{
    'url': 'Lien web',
    'text': 'Texte',
    'phone': 'Téléphone',
    'email': 'Email',
  };

  final _value = TextEditingController();
  String _type = 'url';
  bool _lock = false;
  bool _writing = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    NfcService.cancel();
    _value.dispose();
    super.dispose();
  }

  /// Ajoute le préfixe attendu par le tag (tel:, mailto:) si l'utilisateur ne l'a pas saisi.
  (String, String) _payload() {
    final raw = _value.text.trim();
    switch (_type) {
      case 'phone':
        return ('url', raw.startsWith('tel:') ? raw : 'tel:$raw');
      case 'email':
        return ('url', raw.startsWith('mailto:') ? raw : 'mailto:$raw');
      case 'url':
        final withScheme =
            raw.startsWith('http://') || raw.startsWith('https://')
                ? raw
                : 'https://$raw';
        return ('url', withScheme);
      default:
        return ('text', raw);
    }
  }

  Future<bool> _confirmOverwrite(String uid, int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Ce tag contient déjà des données'),
            content: const Text('Voulez-vous les remplacer ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Remplacer'),
              ),
            ],
          ),
    );
    return result == true;
  }

  Future<void> _write() async {
    if (_value.text.trim().isEmpty) {
      setState(() {
        _ok = false;
        _message = 'Saisissez d’abord la donnée à écrire.';
      });
      return;
    }
    final (dataType, payload) = _payload();
    setState(() {
      _writing = true;
      _message = null;
    });
    final result = await NfcService.writeOnce(
      dataType: dataType,
      payload: payload,
      lockAfterWrite: _lock,
      confirmOverwrite: _confirmOverwrite,
    );
    if (!mounted) return;
    setState(() {
      _writing = false;
      _ok = result.verified;
      _message =
          result.verified
              ? 'Carte écrite et vérifiée${result.locked ? ' (verrouillée)' : ''}. UID ${result.uid}.${result.error == null ? '' : ' ${result.error}'}'
              : (result.error ?? 'Écriture annulée.');
    });
    FeedbackService.signal(success: result.verified);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Écrire une seule carte')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const NfcHelpBanner(),
          Text(
            'Sans dossier ni client. Cette écriture n’est pas enregistrée dans la base.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: 'Type de donnée',
              border: OutlineInputBorder(),
            ),
            items:
                _types.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
            onChanged:
                _writing ? null : (value) => setState(() => _type = value!),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _value,
            enabled: !_writing,
            keyboardType:
                _type == 'phone'
                    ? TextInputType.phone
                    : _type == 'email'
                    ? TextInputType.emailAddress
                    : _type == 'url'
                    ? TextInputType.url
                    : TextInputType.multiline,
            maxLines: _type == 'text' ? 4 : 1,
            decoration: InputDecoration(
              labelText: _types[_type],
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _lock,
            title: const Text('Verrouiller la carte après écriture'),
            subtitle: const Text('Action définitive sur la carte physique.'),
            onChanged: _writing ? null : (value) => setState(() => _lock = value),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _writing ? null : _write,
            icon: const Icon(Icons.nfc_rounded),
            label: Text(
              _writing ? 'Approchez la carte…' : 'Écrire sur la carte',
            ),
          ),
          if (_writing) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: NfcService.cancel,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Annuler'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  _ok ? Icons.verified_rounded : Icons.error_outline,
                  color: _ok ? Colors.green : Theme.of(context).colorScheme.error,
                ),
                title: Text(_ok ? 'Succès' : 'Échec'),
                subtitle: Text(_message!),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
