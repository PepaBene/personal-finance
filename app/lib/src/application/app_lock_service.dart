import 'dart:typed_data';

/// Local app-lock / key-management port (docs/13 §6, FR-SEC-01/02).
///
/// The passphrase is stretched with Argon2id into the master key that opens the
/// encrypted local database. The plaintext key lives in memory only while
/// unlocked. Phase 0 ships the unlock skeleton; biometric unlock (FR-SEC-03)
/// and auto-lock (FR-SEC-05) layer on in Phase 4.
enum LockState { uninitialized, locked, unlocked }

/// Result of first-run setup: the DB key (held in memory) and the one-time
/// recovery code to surface to the user for safe-keeping (FR-AUTH-07).
class KeySetup {
  const KeySetup({required this.key, required this.recoveryCode});
  final Uint8List key;
  final String recoveryCode;
}

abstract interface class AppLockService {
  LockState get state;

  Stream<LockState> watch();

  /// First run: establish a passphrase, generate a random data-encryption key
  /// (DEK), wrap it under the passphrase and under a fresh recovery code, and
  /// persist both wrapped forms (docs/09 §3). Returns the DEK plus the recovery
  /// code to show once.
  Future<KeySetup> initialize(String passphrase);

  /// Subsequent runs: unwrap the DEK with the passphrase and unlock.
  /// Returns the DB key on success; throws [InvalidPassphrase] on failure.
  Future<Uint8List> unlock(String passphrase);

  /// Recover access with the recovery code and set a new passphrase, re-wrapping
  /// the existing DEK (no data is re-encrypted). Returns the DB key; throws
  /// [InvalidRecoveryCode] if the code is wrong/malformed.
  Future<Uint8List> recoverWithCode({
    required String recoveryCode,
    required String newPassphrase,
  });

  /// Change the passphrase by re-wrapping the DEK; throws [InvalidPassphrase]
  /// if [oldPassphrase] is wrong. Requires the app to be initialized.
  Future<void> changePassphrase({
    required String oldPassphrase,
    required String newPassphrase,
  });

  /// Drop the in-memory key (idle auto-lock / explicit lock).
  void lock();

  /// True once a passphrase has been set up on this device.
  Future<bool> isInitialized();

  // --- Biometric unlock (FR-SEC-03) -------------------------------------
  // The DB [key] is stored in OS-secure storage and access is gated by a
  // biometric/local check (performed by BiometricService) before
  // [unlockWithBiometricKey] is called. The passphrase is always a fallback.

  /// Store [key] so the user can later unlock with biometrics.
  Future<void> enrollBiometric(Uint8List key);

  /// Whether a biometric-unlock key is stored on this device.
  Future<bool> isBiometricEnrolled();

  /// Return the stored key and mark the app unlocked. Call only *after* a
  /// successful biometric check. Throws [StateError] if nothing is enrolled.
  Future<Uint8List> unlockWithBiometricKey();

  /// Remove the stored biometric-unlock key.
  Future<void> clearBiometric();
}

class InvalidPassphrase implements Exception {
  const InvalidPassphrase();
  @override
  String toString() => 'InvalidPassphrase';
}

class InvalidRecoveryCode implements Exception {
  const InvalidRecoveryCode();
  @override
  String toString() => 'InvalidRecoveryCode';
}
