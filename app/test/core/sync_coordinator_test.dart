import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/app_lock_service.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/application/sync_service.dart';
import 'package:ledgerly_app/src/core/di/providers.dart';
import 'package:ledgerly_app/src/core/sync/sync_coordinator.dart';

class _FakeAuth implements AuthService {
  final _events = StreamController<AuthEvent>.broadcast();
  AuthState _current = const AuthState.signedOut();

  void emit(AuthEvent e) => _events.add(e);
  set signedIn(bool v) => _current = v
      ? const AuthState(AuthStatus.signedIn, AuthSession(userId: 'u', email: 'e'))
      : const AuthState.signedOut();

  @override
  AuthState get current => _current;
  @override
  Stream<AuthEvent> authEvents() => _events.stream;
  @override
  Stream<AuthState> watch() => Stream.value(_current);
  @override
  Future<void> signIn({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String email, required String password}) async {}
  @override
  Future<void> signOut() async {}
}

class _FakeSync implements SyncService {
  int connects = 0;
  int disconnects = 0;
  int refreshes = 0;

  @override
  Future<void> connect() async => connects++;
  @override
  Future<void> disconnect() async => disconnects++;
  @override
  Future<void> refreshCredentials() async => refreshes++;
  @override
  Future<void> trigger() async {}
  @override
  Stream<SyncStatus> watchStatus() => const Stream.empty();
}

class _FakeLock implements AppLockService {
  bool locked = false;
  @override
  void lock() => locked = true;
  @override
  LockState get state => LockState.unlocked;
  @override
  Stream<LockState> watch() => const Stream.empty();
  @override
  Future<Uint8List> initialize(String passphrase) async => Uint8List(32);
  @override
  Future<Uint8List> unlock(String passphrase) async => Uint8List(32);
  @override
  Future<bool> isInitialized() async => true;
}

/// Let queued microtasks / FutureProvider resolutions settle (a couple of
/// event-loop turns covers the async override + the coordinator's awaits).
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _FakeAuth auth;
  late _FakeSync sync;
  late _FakeLock lock;
  late ProviderContainer container;

  setUp(() {
    auth = _FakeAuth()..signedIn = true;
    sync = _FakeSync();
    lock = _FakeLock();
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        appLockServiceProvider.overrideWithValue(lock),
        syncServiceProvider.overrideWith((ref) async => sync),
      ],
    );
    addTearDown(container.dispose);
    // Instantiate the coordinator (wires its listeners).
    container.read(syncCoordinatorProvider);
  });

  test('connects once the store is unlocked while signed in', () async {
    expect(sync.connects, 0);
    container.read(databaseKeyProvider.notifier).state = Uint8List(32);
    await _settle();
    expect(sync.connects, 1);
  });

  test('refreshes credentials on token refresh while connected', () async {
    container.read(databaseKeyProvider.notifier).state = Uint8List(32);
    await _settle();

    auth.emit(AuthEvent.tokenRefreshed);
    await _settle();
    expect(sync.refreshes, 1);
  });

  test('does not refresh credentials when not connected', () async {
    // Still locked (no key) → not connected.
    auth.emit(AuthEvent.tokenRefreshed);
    await _settle();
    expect(sync.refreshes, 0);
  });

  test('sign-out disconnects, locks, and clears the key', () async {
    container.read(databaseKeyProvider.notifier).state = Uint8List(32);
    await _settle();
    expect(sync.connects, 1);

    auth.emit(AuthEvent.signedOut);
    await _settle();

    expect(sync.disconnects, 1);
    expect(lock.locked, isTrue);
    expect(container.read(databaseKeyProvider), isNull);
  });
}
