import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../application/attachment_cipher.dart';

/// AES-256-GCM client-side attachment encryption (docs/09 §2/§3, ADR-004).
///
/// The content-encryption key (CEK) is derived from the user's master key
/// (Argon2id output, see [Argon2AppLockService]) via HKDF-SHA256 with a fixed
/// info label, so attachments use a key cryptographically separated from the
/// database key. The same master key + salt always derives the same CEK, which
/// is what lets a second device decrypt synced attachments (docs/09 §3).
class AesGcmAttachmentCipher implements AttachmentCipher {
  AesGcmAttachmentCipher(this._key);

  /// 16-byte GCM authentication tag length.
  static const macLength = 16;

  /// HKDF info label — bump the version if the derivation scheme changes.
  static const _info = 'ledgerly.attachment.v1';

  final SecretKey _key;
  final AesGcm _algorithm = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();

  /// Derive the attachment CEK from the master key (docs/09 §3). [salt] should
  /// be a stable per-account value so every device derives the same key.
  static Future<AesGcmAttachmentCipher> fromMasterKey(
    List<int> masterKey, {
    List<int> salt = const <int>[],
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final cek = await hkdf.deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: salt,
      info: utf8.encode(_info),
    );
    return AesGcmAttachmentCipher(cek);
  }

  @override
  Future<EncryptedBlob> encrypt(Uint8List plaintext) async {
    final digest = await _sha256.hash(plaintext);
    final box = await _algorithm.encrypt(plaintext, secretKey: _key);
    return EncryptedBlob(
      nonce: Uint8List.fromList(box.nonce),
      cipherText: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
      sha256Hex: _hex(digest.bytes),
    );
  }

  @override
  Future<Uint8List> decrypt({
    required Uint8List nonce,
    required Uint8List storageBytes,
  }) async {
    if (storageBytes.length < macLength) {
      throw const FormatException(
          'Encrypted blob is too short to contain a tag.');
    }
    final split = storageBytes.length - macLength;
    final box = SecretBox(
      storageBytes.sublist(0, split),
      nonce: nonce,
      mac: Mac(storageBytes.sublist(split)),
    );
    final clear = await _algorithm.decrypt(box, secretKey: _key);
    return Uint8List.fromList(clear);
  }

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
