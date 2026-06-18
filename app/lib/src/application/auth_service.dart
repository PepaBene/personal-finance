/// Authentication port (docs/03 §5, FR-AUTH). Wraps Supabase Auth in `data/`.

/// Minimal, framework-neutral view of the auth session.
class AuthSession {
  const AuthSession({required this.userId, required this.email});
  final String userId;
  final String email;
}

/// Coarse auth state the router guard switches on.
enum AuthStatus { unknown, signedOut, signedIn }

/// Discrete auth lifecycle events the sync coordinator reacts to. Distinct from
/// [AuthState] (which the router watches) because sync cares specifically about
/// `tokenRefreshed` — when the JWT rotates, PowerSync must pick up the new token
/// or it will eventually sync with a stale one (FR-SYNC-07).
enum AuthEvent { signedIn, signedOut, tokenRefreshed, userUpdated }

class AuthState {
  const AuthState(this.status, [this.session]);
  const AuthState.unknown() : this(AuthStatus.unknown, null);
  const AuthState.signedOut() : this(AuthStatus.signedOut, null);

  final AuthStatus status;
  final AuthSession? session;

  bool get isSignedIn => status == AuthStatus.signedIn && session != null;
}

abstract interface class AuthService {
  /// Emits the current session and every change (sign-in/out, token refresh).
  Stream<AuthState> watch();

  /// Discrete lifecycle events for the sync coordinator (see [AuthEvent]).
  Stream<AuthEvent> authEvents();

  AuthState get current;

  Future<void> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
