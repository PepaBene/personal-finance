/// Platform biometric / local-auth gate (FR-SEC-03). Implemented in `data/` via
/// `local_auth`; the app uses it only to *gate* access to a locally-stored
/// unlock key — the passphrase is always available as a fallback, and web has no
/// biometrics (returns unavailable).
abstract interface class BiometricService {
  /// Whether this device can perform a biometric/local check right now.
  Future<bool> isAvailable();

  /// Prompt for a biometric/local check. Returns true only on success; never
  /// throws (platform errors resolve to false so the UI can fall back).
  Future<bool> authenticate(String reason);
}
