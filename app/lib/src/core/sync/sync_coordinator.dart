import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_service.dart';
import '../di/providers.dart';

/// Single owner of the sync engine's lifecycle (docs/13 §5.4). It reacts to two
/// inputs and is the only place that connects/disconnects PowerSync:
///
///  - **auth events** (sign-in, sign-out, token refresh) from [AuthService];
///  - **unlock state** (the in-memory DB key) from [databaseKeyProvider].
///
/// PowerSync can only connect once the user is *both* signed in (for the JWT)
/// and unlocked (the encrypted store is open). On `tokenRefreshed` it refreshes
/// credentials so sync never runs with a stale token (FR-SYNC-07). On sign-out
/// it disconnects, locks, and drops the key.
class SyncCoordinator {
  SyncCoordinator(this._ref);

  final Ref _ref;
  StreamSubscription<AuthEvent>? _authSub;
  bool _connected = false;

  void start() {
    final auth = _ref.read(authServiceProvider);
    _authSub = auth.authEvents().listen(_onAuthEvent);

    // Connecting depends on unlock too: connect when the key appears, and tear
    // down if it is cleared.
    _ref.listen<Object?>(databaseKeyProvider, (_, next) {
      if (next != null) {
        unawaited(_connect());
      } else {
        unawaited(_disconnect());
      }
    });

    // Already signed in and unlocked at startup (e.g. hot restart).
    if (auth.current.isSignedIn && _ref.read(databaseKeyProvider) != null) {
      unawaited(_connect());
    }
  }

  Future<void> _onAuthEvent(AuthEvent event) async {
    switch (event) {
      case AuthEvent.signedIn:
        if (_ref.read(databaseKeyProvider) != null) await _connect();
      case AuthEvent.tokenRefreshed:
        if (!_connected) return;
        final sync = await _ref.read(syncServiceProvider.future);
        await sync?.refreshCredentials();
      case AuthEvent.signedOut:
        await _disconnect();
        _ref.read(appLockServiceProvider).lock();
        _ref.read(databaseKeyProvider.notifier).state = null;
      case AuthEvent.userUpdated:
        break;
    }
  }

  Future<void> _connect() async {
    if (_connected) return;
    final sync = await _ref.read(syncServiceProvider.future);
    if (sync == null) return; // cloud not configured → offline-only
    await sync.connect();
    _connected = true;
  }

  Future<void> _disconnect() async {
    if (!_connected) return;
    _connected = false;
    // Read the already-built service; the store is still open here because the
    // key has not been cleared yet on the sign-out path.
    final sync = await _ref.read(syncServiceProvider.future);
    await sync?.disconnect();
  }

  void dispose() {
    unawaited(_authSub?.cancel());
  }
}

/// Instantiated once and kept alive for the app's lifetime (watched at the app
/// root). Lazily starting it here wires the listeners.
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(ref)..start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
