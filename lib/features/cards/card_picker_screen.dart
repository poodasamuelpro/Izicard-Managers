import 'package:flutter/material.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/models/nfc_tag.dart';
import 'single_write_screen.dart';

/// Choix d'UNE carte précise à encoder, parmi les cartes encore à écrire du dossier (cache local).
class CardPickerScreen extends StatefulWidget {
  const CardPickerScreen({super.key, required this.tags, required this.profile, required this.batchName});

  final List<NfcTagRecord> tags;
  final NfcProfile profile;
  final String batchName;

  @override
  State<CardPickerScreen> createState() => _CardPickerScreenState();
}

class _CardPickerScreenState extends State<CardPickerScreen> {
  final _search = TextEditingController();
  String _term = '';
  bool _changed = false;
  late List<NfcTagRecord> _tags = widget.tags;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(NfcTagRecord tag) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => SingleWriteScreen(tag: tag, profile: widget.profile, batchName: widget.batchName),
    ));
    if (changed == true) {
      _changed = true;
      // Une carte vérifiée n'est plus à écrire : on la retire de la liste affichée.
      setState(() => _tags = _tags.where((t) => t.id != tag.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = _term.trim().toLowerCase();
    final visible = term.isEmpty
        ? _tags
        : _tags
            .where((t) =>
                t.publicId.toLowerCase().contains(term) ||
                '${t.sequence}' == term ||
                t.payload.toLowerCase().contains(term))
            .toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Choisir une carte')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (value) => setState(() => _term = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Numéro, identifiant ou donnée',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('Aucune carte à écrire ne correspond.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final tag = visible[i];
                            final color = IzicardColors.forTagStatus(tag.status);
                            return Card(
                              child: ListTile(
                                onTap: () => _choose(tag),
                                leading: CircleAvatar(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  child: Text('${tag.sequence}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                ),
                                title: Text(tag.publicId, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(tag.payload, maxLines: 2, overflow: TextOverflow.ellipsis),
                                trailing: const Icon(Icons.nfc_rounded),
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
