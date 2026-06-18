import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../application/auth_service.dart';

/// Supabase-backed [AuthService] (docs/13 §6.1, FR-AUTH-01/02). Sessions (JWT +
/// refresh token) are persisted by `supabase_flutter` in secure storage. RLS
/// keyed to `auth.uid()` enforces tenant isolation server-side (FR-AUTH-03).
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client) {
    _current = _stateFrom(_client.auth.currentSession);
    _sub = _client.auth.onAuthStateChange.listen((event) {
      _current = _stateFrom(event.session);
      _controller.add(_current);
    });
  }

  final sb.SupabaseClient _client;
  final _controller = StreamController<AuthState>.broadcast();
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
