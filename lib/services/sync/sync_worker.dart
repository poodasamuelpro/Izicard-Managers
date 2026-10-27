import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/network/connectivity_service.dart';
import '../../data/repositories/sync_repository.dart';

/// Envoie la file locale vers la base : au démarrage, au retour du réseau,
/// au retour de l'application au premier plan et sur demande.
/// À démarrer après l'authentification d'un profil valide, à arrêter à la déconnexion.
class SyncWorker with WidgetsBindingObserver {
  SyncWorker({
    required ConnectivityService connectivity,
    required SyncRepository repository,
  }) : _connectivity = connectivity,
       _repository = repository;

  final ConnectivityService _connectivity;
  final SyncRepository _repository;
  StreamSubscription<bool>? _subscription;
  bool _running = false;
  bool _syncing = false;

  /// Nombre d'opérations encore en file (en attente + refusées).
  final ValueNotifier<int> pending = ValueNotifier<int>(0);

  Future<void> start() async {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onlineChanges.listen((online) {
      if (online) unawaited(syncNow());
    });
    pending.value = await _safeCount();
    if (await _connectivity.isOnline) await syncNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _running) unawaited(syncNow());
  }

  Future<SyncResult?> syncNow() async {
    if (_syncing) return null;
    _syncing = true;
    try {
      final result = await _repository.syncPending();
      pending.value = result.remaining;
      return result;
    } catch (_) {
      return null;
    } finally {
      _syncing = false;
    }
  }

  Future<int> _safeCount() async {
    try {
      return await _repository.pendingCount();
    } catch (_) {
      return 0;
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    _subscription = null;
    _running = false;
  }
}
