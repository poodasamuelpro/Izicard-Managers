import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/izicard_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/nfc_profile.dart';
import '../../data/models/nfc_tag.dart';
import '../../data/remote/tags_remote.dart';
import '../../data/repositories/write_recorder.dart';
import '../../services/feedback/feedback_service.dart';
import '../../services/nfc/nfc_service.dart';
import '../nfc/nfc_help_banner.dart';

enum _Phase { idle, waiting, success, error }

/// Encode UNE seule carte précise : écriture, relecture comparée, résultat enregistré
/// d'abord en local puis envoyé. Fonctionne hors connexion si le dossier est téléchargé.
class SingleWriteScreen extends StatefulWidget {
  const SingleWriteScreen({
    super.key,
    required this.tag,
    required this.profile,
    this.batchName,
  });

  final NfcTagRecord tag;
  final NfcProfile profile;
  final String? batchName;

  @override
  State<SingleWriteScreen> createState() => _SingleWriteScreenState();
}

class _SingleWriteScreenState extends State<SingleWriteScreen> {
  late final AppDatabase _database;
  late final WriteRecorder _recorder;
  _Phase _phase = _Phase.idle;
  String _message = '';
  bool _lock = false;
  bool _nfcReady = true;
  bool _changed = false;
  int _unsynced = 0;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _database = AppDatabase();
    _recorder = WriteRecorder(
      database: _database,
      remote: TagsRemote(client),
      userId: client.auth.currentUser?.id ?? '',
    );
    _lock = AppSettingsStore.instance.value.lockByDefault;
  }

  @override
  void dispose() {
    unawaited(NfcService.cancel());
    unawaited(FeedbackService.keepAwake(false));
    _database.close();
    super.dispose();
  }

  bool get _canWrite => widget.profile.hasValidAccess && widget.tag.isWritable;

  Future<void> _write() async {
    if (_phase == _Phase.waiting || !_canWrite) return;
    if (_lock) {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              icon: const Icon(Icons.lock_outline_rounded),
              title: const Text('Verrouillage définitif'),
              content: const Text(
                'Ce tag ne pourra plus jamais être réécrit une fois vérifié. Confirmer ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Verrouiller'),
                ),
              ],
            ),
      );
      if (ok != true) return;
    }
    setState(() {
      _phase = _Phase.waiting;
      _message = 'Approchez le tag du dos du téléphone…';
    });
    unawaited(FeedbackService.keepAwake(true));
    final tag = widget.tag;
    final result = await NfcService.writeOnce(
      dataType: tag.dataType,
      payload: tag.payload,
      lockAfterWrite: _lock,
      guard: (uid) => _recorder.guard(tag, uid),
      confirmOverwrite: _confirmOverwrite,
    );
    unawaited(FeedbackService.keepAwake(false));
    if (!mounted) return;
    if (result.cancelled) {
      setState(() {
        _phase = _Phase.idle;
        _message = '';
      });
      return;
    }
    if (result.verified) {
      _unsynced = await _recorder.record(
        tag,
        status: 'verified',
        uid: result.uid,
        lockTag: result.locked,
      );
      _changed = true;
      unawaited(FeedbackService.signal(success: true));
      if (!mounted) return;
      setState(() {
        _phase = _Phase.success;
        _message =
            'Carte n° ${tag.sequence} vérifiée · UID ${result.uid}${result.locked ? ' · verrouillée' : ''}'
            '${result.error != null ? '\n${result.error}' : ''}';
      });
    } else {
      final text = result.error ?? 'Écriture non vérifiée.';
      if (result.recordable) {
        _unsynced = await _recorder.record(
          tag,
          status: 'error',
          uid: result.uid.isEmpty ? null : result.uid,
          lockTag: false,
          error: text,
        );
        _changed = true;
      }
      unawaited(FeedbackService.signal(success: false));
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _message = text;
      });
    }
  }

  Future<bool> _confirmOverwrite(String uid, int existingRecordCount) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                icon: const Icon(Icons.warning_amber_rounded),
                title: const Text('Tag déjà utilisé'),
                content: Text(
                  'Le tag $uid contient déjà $existingRecordCount enregistrement(s) NDEF. '
                  'La nouvelle donnée remplacera son contenu actuel. Continuer ?',
                ),
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
        ) ??
        false;
  }

  Future<void> _cancel() async {
    await NfcService.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final (color, icon) = switch (_phase) {
      _Phase.success => (
        IzicardColors.statusVerified,
        Icons.check_circle_rounded,
      ),
      _Phase.error => (IzicardColors.statusError, Icons.error_rounded),
      _Phase.waiting => (IzicardColors.statusPending, Icons.nfc_rounded),
      _Phase.idle => (IzicardColors.statusWritten, Icons.nfc_rounded),
    };
    return PopScope(
      canPop: _phase != _Phase.waiting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _cancel();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Encoder la carte n° ${tag.sequence}')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  NfcHelpBanner(
                    onChanged: (ready) => setState(() => _nfcReady = ready),
                  ),
                  Text(
                    tag.publicId,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.batchName != null)
                    Text(
                      widget.batchName!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Donnée à écrire',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(tag.payload),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: Colors.white, size: 60),
                        const SizedBox(height: 10),
                        Text(
                          _phase == _Phase.idle
                              ? (_canWrite
                                  ? 'Prêt à encoder cette carte'
                                  : 'Cette carte ne peut pas être écrite')
                              : _message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_phase == _Phase.idle && !_canWrite) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.profile.hasValidAccess
                                ? 'Statut : ${IzicardColors.labelForTagStatus(tag.status)}${tag.locked ? ' (verrouillée)' : ''}.'
                                : 'Votre accès n’est plus actif.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_unsynced > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_unsynced résultat(s) en attente de synchronisation.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_phase != _Phase.success && _canWrite)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _lock,
                      onChanged:
                          _phase == _Phase.waiting
                              ? null
                              : (value) => setState(() => _lock = value),
                      title: const Text('Verrouiller définitivement ce tag'),
                      subtitle: const Text(
                        'Irréversible. Appliqué seulement après une relecture réussie.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_phase == _Phase.success)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                      ),
                      onPressed: () => Navigator.of(context).pop(_changed),
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Terminé'),
                    )
                  else if (_phase == _Phase.waiting)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                      ),
                      onPressed: _cancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Annuler'),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                      ),
                      onPressed: _canWrite && _nfcReady ? _write : null,
                      icon: Icon(
                        _phase == _Phase.error
                            ? Icons.refresh_rounded
                            : Icons.nfc_rounded,
                      ),
                      label: Text(
                        _phase == _Phase.error
                            ? 'Réessayer'
                            : 'Écrire cette carte',
                      ),
                    ),
                  if (_phase == _Phase.error || _phase == _Phase.idle)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_changed),
                      child: const Text('Retour'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
