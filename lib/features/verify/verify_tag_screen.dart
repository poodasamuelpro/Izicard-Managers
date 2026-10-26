import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_tag.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/remote/tags_remote.dart';
import '../../services/nfc/ndef_builder.dart';
import '../../services/nfc/nfc_service.dart';

class VerifyTagScreen extends StatefulWidget {
  const VerifyTagScreen({super.key});

  @override
  State<VerifyTagScreen> createState() => _VerifyTagScreenState();
}

class _VerifyTagScreenState extends State<VerifyTagScreen> {
  late final TagRepository _tags;
  bool _reading = false;
  String? _error;
  String? _uid;
  String? _result;
  NfcTagRecord? _expected;

  @override
  void initState() {
    super.initState();
    _tags = TagRepository(TagsRemote(Supabase.instance.client));
  }

  Future<void> _verify() async {
    setState(() {
      _reading = true;
      _error = null;
      _result = null;
      _uid = null;
      _expected = null;
    });
    try {
      final read = await NfcService.readOnce();
      final tag = await _tags.findByUid(read.uid);
      if (!mounted) return;
      setState(() {
        _uid = read.uid;
        _expected = tag;
        if (tag == null) {
          _result = 'Tag inconnu dans le backend.';
        } else if (tag.locked) {
          _result = 'Tag déjà verrouillé : vérification en lecture seule.';
        } else if (read.message == null) {
          _result = 'Le tag ne contient aucun enregistrement NDEF.';
        } else {
          final expected = NdefPayloadBuilder.build(dataType: tag.dataType, payload: tag.payload);
          _result = read.message == expected ? 'Contenu conforme.' : 'Contenu différent du payload attendu.';
        }
      });
    } catch (exception) {
      if (mounted) setState(() => _error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOk = _result == 'Contenu conforme.';
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier un tag')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: IzicardColors.paleCyan,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                const Icon(Icons.fact_check_rounded, size: 42, color: IzicardColors.cyan),
                const SizedBox(height: 12),
                const Text('La vérification lit le tag, retrouve sa carte par UID et compare le contenu réel au payload backend.', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _reading ? null : _verify,
                  icon: Icon(_reading ? Icons.hourglass_top_rounded : Icons.nfc_rounded),
                  label: Text(_reading ? 'Approchez le tag…' : 'Lire et vérifier'),
                ),
              ]),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ResultCard(color: Colors.red, icon: Icons.error_outline, title: 'Erreur de lecture', message: _error!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(
              color: isOk ? IzicardColors.success : Colors.orange,
              icon: isOk ? Icons.verified_rounded : Icons.warning_amber_rounded,
              title: isOk ? 'Conforme' : 'À contrôler',
              message: _result!,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _InfoLine(label: 'UID physique', value: _uid ?? 'Inconnu'),
                  if (_expected != null) ...[
                    _InfoLine(label: 'Carte', value: _expected!.publicId),
                    _InfoLine(label: 'Dossier', value: _expected!.batchId),
                    _InfoLine(label: 'Statut backend', value: _expected!.status),
                    _InfoLine(label: 'Payload attendu', value: _expected!.payload),
                  ],
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.color, required this.icon, required this.title, required this.message});
  final Color color;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(leading: Icon(icon, color: color), title: Text(title), subtitle: Text(message)),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(value),
        ]),
      );
}
