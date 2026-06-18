import 'dart:convert';
import 'dart:typed_data';

/// A client-side-encrypted attachment blob (docs/09 §2, FR-SEC-01). The bytes
/// are AES-256-GCM ciphertext the server can never read; only [nonce] + the
/// authentication [mac] + the content key are needed to recover the plaintext.
///
/// Maps onto the Attachment row (docs/04 §2.6): [nonceBase64] → `encNonce`,
/// [sha256Hex] → `sha256`, and [storageBytes] is the object uploaded to
/// Supabase Storage.
class EncryptedBlob {
  EncryptedBlob({
    required this.nonce,
    required this.cipherText,
    required this.mac,
    required this.sha256Hex,
  });

  /// 12-byte GCM nonce/IV (unique per encryption; not secret).
  final Uint8List nonce;

  /// Ciphertext without the authentication tag.
  final Uint8List cipherText;

  /// 16-byte GCM authentication tag.
  final Uint8List mac;

  /// Lowercase hex SHA-256 of the **plaintext** — for dedupe + integrity
  /// (docs/09 §7). Stable across re-encryptions of the same file.
  final String sha256Hex;

  /// The self-contained object to store/upload: `ciphertext || tag`.
  Uint8List get storageBytes => Uint8List.fromList([...cipherText, ...mac]);

  /// Base64 nonce for the `Attachment.encNonce` column.
  String get nonceBase64 => base64Encode(nonce);
}

/// Encrypts/decrypts attachment bytes with the user's content key (docs/09 §3).
/// Implemented in `data/crypto`; the key never leaves the device and is held in
/// memory only while unlocked.
abstract interface class AttachmentCipher {
  /// Encrypt [plaintext] under a fresh random nonce.
  Future<EncryptedBlob> encrypt(Uint8List plaintext);

  /// Decrypt a stored blob. Throws if the content key is wrong or the bytes
  /// were tampered with (GCM authentication failure).
  ///
  /// [storageBytes] is `ciphertext || tag` as produced by
  /// [EncryptedBlob.storageBytes]; [nonce] is the stored `encNonce`.
  Future<Uint8List> decrypt({
    required Uint8List nonce,
    required Uint8List storageBytes,
  });
}
