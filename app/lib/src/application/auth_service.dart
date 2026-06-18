/// Authentication port (docs/03 §5, FR-AUTH). Wraps Supabase Auth in `data/`.

/// Minimal, framework-neutral view of the auth session.
class AuthSession {
  const AuthSession({required this.userId, required this.email});
  final String userId;
  final String email;
}

/// Coarse auth state the router guard switches on.
enum AuthStatus { unknown, signedOut, signedIn }

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

  AuthState get current;

  Future<void> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
