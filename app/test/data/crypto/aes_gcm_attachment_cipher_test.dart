import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/data/crypto/aes_gcm_attachment_cipher.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  // A deterministic 32-byte content key for the cipher under test.
  final key = SecretKey(List<int>.filled(32, 7));
  final cipher = AesGcmAttachmentCipher(key);

  test('round-trips plaintext through encrypt/decrypt', () async {
    final plain = _bytes('Albert receipt — CELKEM 234,10 Kč');
    final blob = await cipher.encrypt(plain);
    final back = await cipher.decrypt(
      nonce: blob.nonce,
      storageBytes: blob.storageBytes,
    );
    expect(back, plain);
  });

  test('round-trips empty input and matches the known SHA-256 of ""', () async {
    final blob = await cipher.encrypt(Uint8List(0));
    expect(
      blob.sha256Hex,
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    final back = await cipher.decrypt(
      nonce: blob.nonce,
      storageBytes: blob.storageBytes,
    );
    expect(back, isEmpty);
  });

  test('uses a fresh nonce each time but a stable plaintext hash', () async {
    final plain = _bytes('same bytes');
    final a = await cipher.encrypt(plain);
    final b = await cipher.encrypt(plain);
    expect(a.nonce, isNot(b.nonce)); // unique IVs
    expect(a.storageBytes, isNot(b.storageBytes)); // semantic security
    expect(a.sha256Hex, b.sha256Hex); // dedupe key is stable
    expect(a.nonce.length, 12);
    expect(a.mac.length, AesGcmAttachmentCipher.macLength);
  });

  test('detects tampering (GCM auth failure)', () async {
    final blob = await cipher.encrypt(_bytes('integrity matters'));
    final tampered = Uint8List.fromList(blob.storageBytes);
    tampered[0] ^= 0xFF; // flip a ciphertext bit
    expect(
      () => cipher.decrypt(nonce: blob.nonce, storageBytes: tampered),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('a different key cannot decrypt the blob', () async {
    final blob = await cipher.encrypt(_bytes('secret'));
    final other = AesGcmAttachmentCipher(SecretKey(List<int>.filled(32, 9)));
    expect(
      () => other.decrypt(nonce: blob.nonce, storageBytes: blob.storageBytes),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('rejects a blob shorter than the GCM tag', () async {
    expect(
      () => cipher.decrypt(
        nonce: Uint8List(12),
        storageBytes: Uint8List(4),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  group('fromMasterKey (HKDF)', () {
    final master = List<int>.filled(32, 42);

    test('same master key + salt derives an interoperable key', () async {
      final salt = _bytes('account-salt');
      final deviceA = await AesGcmAttachmentCipher.fromMasterKey(
        master,
        salt: salt,
      );
      final deviceB = await AesGcmAttachmentCipher.fromMasterKey(
        master,
        salt: salt,
      );
      final blob = await deviceA.encrypt(_bytes('cross-device'));
      final back = await deviceB.decrypt(
        nonce: blob.nonce,
        storageBytes: blob.storageBytes,
      );
      expect(back, _bytes('cross-device'));
    });

    test('a different salt derives a different, non-interoperable key',
        () async {
      final a = await AesGcmAttachmentCipher.fromMasterKey(
        master,
        salt: _bytes('salt-a'),
      );
      final b = await AesGcmAttachmentCipher.fromMasterKey(
        master,
        salt: _bytes('salt-b'),
      );
      final blob = await a.encrypt(_bytes('isolated'));
      expect(
        () => b.decrypt(nonce: blob.nonce, storageBytes: blob.storageBytes),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
