import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/app_lock_service.dart';

/// Argon2id-backed local app lock (docs/13 §6.4, FR-SEC-02).
///
/// Phase 0 scope: passphrase -> Argon2id(salt) -> 32-byte database key that
/// opens the encrypted Drift DB. The salt and a non-secret verifier are kept in
/// OS-backed secure storage (Keychain / Keystore / DPAPI / libsecret). The
/// plaintext key is held in memory only while unlocked.
///
/// Out of Phase 0 scope (Phase 4, docs/09 §3): wrapping a separate DEK,
/// recovery-phrase escrow, multi-device key wrapping, biometric unlock.
class Argon2AppLockService implements AppLockService {
  Argon2AppLockService(this._storage);

  final FlutterSecureStorage _storage;
  final _controller = StreamController<LockState>.broadcast();

  static const _saltKey = 'ledgerly.kdf.salt';
  static const _verifierKey = 'ledgerly.kdf.verifier';

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
      (await _storage.read(key: _saltKey)) != null;

  @override
  Future<Uint8List> initialize(String passphrase) async {
    final salt = _randomBytes(16);
    final key = await _deriveKey(passphrase, salt);
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _verifierKey, value: await _verifier(key));
    _setUnlocked(key);
    return key;
  }

  @override
  Future<Uint8List> unlock(String passphrase) async {
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
  void lock() {
    final key = _key;
    if (key != null) {
      key.fillRange(0, key.length, 0); // best-effort zeroization
    }
    _key = null;
    _state = LockState.locked;
    _controller.add(_state);
  }

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

  Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rng.nextInt(256)));
  }
}
