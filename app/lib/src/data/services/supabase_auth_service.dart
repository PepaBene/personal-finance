import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../application/auth_service.dart';

/// Supabase-backed [AuthService] (docs/13 §6.1, FR-AUTH-01/02). Sessions (JWT +
/// refresh token) are persisted by `supabase_flutter` in secure storage. RLS
/// keyed to `auth.uid()` enforces tenant isolation server-side (FR-AUTH-03).
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client) {
    _current = _stateFrom(_client.auth.currentSession);
    _sub = _client.auth.onAuthStateChange.listen((data) {
      _current = _stateFrom(data.session);
      _controller.add(_current);
      final event = _eventFrom(data.event);
      if (event != null) _events.add(event);
    });
  }

  final sb.SupabaseClient _client;
  final _controller = StreamController<AuthState>.broadcast();
  final _events = StreamController<AuthEvent>.broadcast();
  late StreamSubscription<sb.AuthState> _sub;
  AuthState _current = const AuthState.unknown();

  @override
  AuthState get current => _current;

  @override
  Stream<AuthState> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Stream<AuthEvent> authEvents() => _events.stream;

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Future<void> dispose() async {
    await _sub.cancel();
    await _controller.close();
    await _events.close();
  }

  /// Maps Supabase's [sb.AuthChangeEvent] to our coarser [AuthEvent]; events we
  /// don't act on (password recovery, MFA challenge) return null.
  AuthEvent? _eventFrom(sb.AuthChangeEvent event) {
    return switch (event) {
      sb.AuthChangeEvent.signedIn || sb.AuthChangeEvent.initialSession =>
        _current.isSignedIn ? AuthEvent.signedIn : null,
      sb.AuthChangeEvent.signedOut => AuthEvent.signedOut,
      sb.AuthChangeEvent.tokenRefreshed => AuthEvent.tokenRefreshed,
      sb.AuthChangeEvent.userUpdated => AuthEvent.userUpdated,
      _ => null,
    };
  }

  AuthState _stateFrom(sb.Session? session) {
    final user = session?.user;
    if (session == null || user == null) {
      return const AuthState.signedOut();
    }
    return AuthState(
      AuthStatus.signedIn,
      AuthSession(userId: user.id, email: user.email ?? ''),
    );
  }
}
