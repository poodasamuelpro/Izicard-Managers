import 'dart:async';

import '../../core/network/connectivity_service.dart';
import '../../data/repositories/sync_repository.dart';

class SyncWorker {
  SyncWorker({required ConnectivityService connectivity, required SyncRepository repository})
      : _connectivity = connectivity,
        _repository = repository;

  final ConnectivityService _connectivity;
  final SyncRepository _repository;
  StreamSubscription<bool>? _subscription;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _subscription = _connectivity.onlineChanges.listen((online) {
      if (online) unawaited(syncNow());
    });
    if (await _connectivity.isOnline) await syncNow();
  }

  Future<SyncResult?> syncNow() async {
    try {
      return await _repository.syncPending();
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _running = false;
  }
}
