import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'recovery_code.dart';

/// A data-encryption key (DEK) wrapped (encrypted) under a key-encryption key
/// (KEK). AES-256-GCM ciphertext + nonce + MAC, plus the salt used to derive the
/// KEK. Stored as opaque JSON; the plaintext DEK is never persisted (docs/09 §3).
class WrappedDek {
  const WrappedDek({
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> salt;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, dynamic> toJson() => {
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'ct': base64Encode(cipherText),
        'mac': base64Encode(mac),
      };

  factory WrappedDek.fromJson(Map<String, dynamic> json) => WrappedDek(
        salt: base64Decode(json['salt'] as String),
        nonce: base64Decode(json['nonce'] as String),
        cipherText: base64Decode(json['ct'] as String),
        mac: base64Decode(json['mac'] as String),
      );

  String encode() => jsonEncode(toJson());
  static WrappedDek decode(String raw) =>
      WrappedDek.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Result of first-time key setup: the live DEK to open the DB, the recovery
/// code to show the user once, and the two wrapped forms to persist.
class KeyEnrollment {
  const KeyEnrollment({
    required this.dek,
    required this.recoveryCode,
    required this.passphraseWrap,
    required this.recoveryWrap,
  });

  final Uint8List dek;
  final String recoveryCode;
  final WrappedDek passphraseWrap;
  final WrappedDek recoveryWrap;
}

/// Thrown when a wrap can't be opened with the supplied passphrase/recovery
/// code (wrong secret → GCM authentication fails).
class WrongKeyException implements Exception {
  const WrongKeyException();
  @override
  String toString() => 'WrongKeyException';
}

/// Envelope key management (docs/09 §3, ADR-012, FR-AUTH-07). A random per-
/// account **DEK** opens the local DB and roots content encryption. The DEK is
/// **wrapped** under a passphrase-derived key (Argon2id) and, independently,
/// under a recovery-code-derived key (HKDF over 160 bits of entropy). A new
/// device unwraps with either secret; the plaintext DEK never leaves the device.
/// Changing the passphrase only re-wraps the DEK — no data is re-encrypted.
class KeyManager {
  KeyManager({Argon2id? passphraseKdf})
      : _argon = passphraseKdf ??
            Argon2id(
              memory: 19456, // 19 MiB (OWASP baseline)
              iterations: 2,
              parallelism: 1,
              hashLength: 32,
            );

  final Argon2id _argon;
  final _aes = AesGcm.with256bits();

  static const _dekLength = 32;
  static const _saltLength = 16;
  static const _nonceLength = 12;

  /// First-time setup: random DEK + recovery code, wrapped under both secrets.
  Future<KeyEnrollment> createAccount(String passphrase) async {
    final dek = _random(_dekLength);
    final recovery = RecoveryCode.generate();
    final passWrap = await wrapForPassphrase(dek, passphrase);
    final recoveryWrap = await _wrapForRecovery(dek, recovery.bytes);
    return KeyEnrollment(
      dek: dek,
      recoveryCode: recovery.formatted,
      passphraseWrap: passWrap,
      recoveryWrap: recoveryWrap,
    );
  }

  /// Unwrap the DEK with the passphrase; throws [WrongKeyException] if wrong.
  Future<Uint8List> unwrapWithPassphrase(
    String passphrase,
    WrappedDek wrap,
  ) async {
    final kek = await _deriveFromPassphrase(passphrase, wrap.salt);
    return _unwrap(wrap, kek);
  }

  /// Unwrap the DEK with the recovery code; throws [WrongKeyException] if wrong
  /// or [FormatException] if the code is malformed.
  Future<Uint8List> unwrapWithRecovery(String code, WrappedDek wrap) async {
    final bytes = RecoveryCode.parse(code).bytes;
    final kek = await _deriveFromRecovery(bytes, wrap.salt);
    return _unwrap(wrap, kek);
  }

  /// Re-wrap an existing [dek] under a (new) passphrase — passphrase change /
  /// recovery, without re-encrypting any content.
  Future<WrappedDek> wrapForPassphrase(
    Uint8List dek,
    String passphrase,
  ) async {
    final salt = _random(_saltLength);
    final kek = await _deriveFromPassphrase(passphrase, salt);
    return _wrap(dek, kek, salt);
  }

  Future<WrappedDek> _wrapForRecovery(
    Uint8List dek,
    Uint8List recoveryBytes,
  ) async {
    final salt = _random(_saltLength);
    final kek = await _deriveFromRecovery(recoveryBytes, salt);
    return _wrap(dek, kek, salt);
  }

  Future<WrappedDek> _wrap(
    Uint8List dek,
    Uint8List kek,
    Uint8List salt,
  ) async {
    final box = await _aes.encrypt(
      dek,
      secretKey: SecretKey(kek),
      nonce: _random(_nonceLength),
    );
    return WrappedDek(
      salt: salt,
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  Future<Uint8List> _unwrap(WrappedDek wrap, Uint8List kek) async {
    final box = SecretBox(
      wrap.cipherText,
      nonce: wrap.nonce,
      mac: Mac(wrap.mac),
    );
    try {
      final clear = await _aes.decrypt(box, secretKey: SecretKey(kek));
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const WrongKeyException();
    }
  }

  /// Expensive KDF for the (low-entropy) passphrase.
  Future<Uint8List> _deriveFromPassphrase(
    String passphrase,
    List<int> salt,
  ) async {
    final key = await _argon.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Cheap KDF (HKDF) suffices for the high-entropy recovery code.
  Future<Uint8List> _deriveFromRecovery(
    List<int> recoveryBytes,
    List<int> salt,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(recoveryBytes),
      nonce: salt,
      info: utf8.encode('ledgerly.recovery.v1'),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  Uint8List _random(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rng.nextInt(256)));
  }
}
