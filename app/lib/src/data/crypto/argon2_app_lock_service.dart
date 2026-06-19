import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/app_lock_service.dart';
import 'key_manager.dart';

/// Argon2id-backed local app lock with envelope key management (docs/09 §3,
/// docs/13 §6.4, FR-SEC-02, FR-AUTH-07).
///
/// A random per-account **DEK** opens the encrypted Drift DB. The DEK is wrapped
/// under the passphrase (Argon2id) and, independently, under a recovery code, so
/// a forgotten passphrase is recoverable and a passphrase change only re-wraps
/// the DEK. Wrapped blobs live in OS-secure storage (Keychain / Keystore / DPAPI
/// / libsecret); the plaintext DEK is held in memory only while unlocked.
///
/// A legacy unlock path (passphrase → Argon2id → key, with a stored verifier)
/// is retained so installs created before the envelope model still open.
class Argon2AppLockService implements AppLockService {
  Argon2AppLockService(this._storage, {KeyManager? keyManager})
      : _km = keyManager ?? KeyManager();

  final FlutterSecureStorage _storage;
  final KeyManager _km;
  final _controller = StreamController<LockState>.broadcast();

  static const _saltKey = 'ledgerly.kdf.salt';
  static const _verifierKey = 'ledgerly.kdf.verifier';
  static const _bioKeyKey = 'ledgerly.bio.key';
  static const _passWrapKey = 'ledgerly.dek.passwrap';
  static const _recWrapKey = 'ledgerly.dek.recwrap';

  // OWASP-tuned Argon2id baseline (revisit per-platform in docs/10).
  static final _kdf = Argon2id(
    memory: 19456, // 19 MiB
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  );

  LockState _state = LockState.uninitialized;
  Uint8List? _key;

  @override
  LockState get state => _state;

  @override
  Stream<LockState> watch() => _controller.stream;

  @override
  Future<bool> isInitialized() async =>
      (await _storage.read(key: _passWrapKey)) != null ||
      (await _storage.read(key: _saltKey)) != null;

  @override
  Future<KeySetup> initialize(String passphrase) async {
    final enrollment = await _km.createAccount(passphrase);
    await _storage.write(
      key: _passWrapKey,
      value: enrollment.passphraseWrap.encode(),
    );
    await _storage.write(
      key: _recWrapKey,
      value: enrollment.recoveryWrap.encode(),
    );
    _setUnlocked(enrollment.dek);
    return KeySetup(key: enrollment.dek, recoveryCode: enrollment.recoveryCode);
  }

  @override
  Future<Uint8List> unlock(String passphrase) async {
    final passWrapRaw = await _storage.read(key: _passWrapKey);
    if (passWrapRaw != null) {
      try {
        final dek = await _km.unwrapWithPassphrase(
          passphrase,
          WrappedDek.decode(passWrapRaw),
        );
        _setUnlocked(dek);
        return dek;
      } on WrongKeyException {
        throw const InvalidPassphrase();
      }
    }
    return _legacyUnlock(passphrase);
  }

  /// Pre-envelope installs: passphrase → Argon2id(salt) → key, checked against a
  /// stored verifier.
  Future<Uint8List> _legacyUnlock(String passphrase) async {
    final saltB64 = await _storage.read(key: _saltKey);
    final storedVerifier = await _storage.read(key: _verifierKey);
    if (saltB64 == null || storedVerifier == null) {
      throw StateError('App lock not initialized; call initialize() first.');
    }
    final salt = base64Decode(saltB64);
    final key = await _deriveKey(passphrase, salt);
    if (await _verifier(key) != storedVerifier) {
      throw const InvalidPassphrase();
    }
    _setUnlocked(key);
    return key;
  }

  @override
  Future<Uint8List> recoverWithCode({
    required String recoveryCode,
    required String newPassphrase,
  }) async {
    final recWrapRaw = await _storage.read(key: _recWrapKey);
    if (recWrapRaw == null) {
      throw StateError('No recovery wrap stored on this device.');
    }
    final Uint8List dek;
    try {
      dek = await _km.unwrapWithRecovery(
        recoveryCode,
        WrappedDek.decode(recWrapRaw),
      );
    } on WrongKeyException {
      throw const InvalidRecoveryCode();
    } on FormatException {
      throw const InvalidRecoveryCode();
    }
    final newWrap = await _km.wrapForPassphrase(dek, newPassphrase);
    await _storage.write(key: _passWrapKey, value: newWrap.encode());
    _setUnlocked(dek);
    return dek;
  }

  @override
  Future<void> changePassphrase({
    required String oldPassphrase,
    required String newPassphrase,
  }) async {
    final passWrapRaw = await _storage.read(key: _passWrapKey);
    if (passWrapRaw == null) {
      throw StateError('Passphrase change requires the envelope key model.');
    }
    final Uint8List dek;
    try {
      dek = await _km.unwrapWithPassphrase(
        oldPassphrase,
        WrappedDek.decode(passWrapRaw),
      );
    } on WrongKeyException {
      throw const InvalidPassphrase();
    }
    final newWrap = await _km.wrapForPassphrase(dek, newPassphrase);
    await _storage.write(key: _passWrapKey, value: newWrap.encode());
  }

  @override
  void lock() {
    final key = _key;
    if (key != null) {
      key.fillRange(0, key.length, 0); // best-effort zeroization
    }
    _key = null;
    _state = LockState.locked;
    _controller.add(_state);
  }

  @override
  Future<void> enrollBiometric(Uint8List key) =>
      _storage.write(key: _bioKeyKey, value: base64Encode(key));

  @override
  Future<bool> isBiometricEnrolled() async =>
      (await _storage.read(key: _bioKeyKey)) != null;

  @override
  Future<Uint8List> unlockWithBiometricKey() async {
    final stored = await _storage.read(key: _bioKeyKey);
    if (stored == null) {
      throw StateError('No biometric key enrolled.');
    }
    final key = Uint8List.fromList(base64Decode(stored));
    _setUnlocked(key);
    return key;
  }

  @override
  Future<void> clearBiometric() => _storage.delete(key: _bioKeyKey);

  void _setUnlocked(Uint8List key) {
    _key = key;
    _state = LockState.unlocked;
    _controller.add(_state);
  }

  Future<Uint8List> _deriveKey(String passphrase, List<int> salt) async {
    final secret = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await secret.extractBytes());
  }

  /// Non-secret value proving the passphrase derives the same key, without
  /// storing the key itself. SHA-256 of the derived key is sufficient here.
  Future<String> _verifier(Uint8List key) async {
    final hash = await Sha256().hash(key);
    return base64Encode(hash.bytes);
  }
}
