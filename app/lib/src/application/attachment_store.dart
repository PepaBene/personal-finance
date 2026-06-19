import 'dart:typed_data';

import '../domain/entities/attachment.dart';
import '../domain/enums.dart';

export 'attachment_cipher.dart' show AttachmentCipher, EncryptedBlob;

/// Remote blob storage for encrypted attachments (Supabase Storage, docs/09 §2).
/// Only ever sees opaque ciphertext — keys are per-user object paths.
abstract interface class RemoteBlobStore {
  /// Whether a cloud backend is configured (offline-only when false).
  bool get isAvailable;

  Future<void> upload(String key, Uint8List bytes);
  Future<Uint8List> download(String key);
  Future<void> remove(String key);
}

/// Local cache of encrypted blob bytes, keyed by attachment id. Keeps scanning
/// fully available offline and avoids re-downloading (docs/05 §5).
abstract interface class BlobCache {
  Future<bool> contains(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<Uint8List?> read(String key);
  Future<void> remove(String key);
}

/// Stores and loads attachment blobs with client-side AES-256-GCM (docs/09 §2,
/// ADR-004): encrypt → cache locally → upload opaque ciphertext to Storage; load
/// decrypts from the cache (else downloads, then caches). The server never sees
/// plaintext. Implemented in `data/attachments`.
abstract interface class AttachmentStore {
  /// Encrypt [bytes], cache locally, upload when a remote is available, and
  /// return the metadata row to persist (link [transactionId] now or later).
  Future<AttachmentEntity> save({
    required Uint8List bytes,
    required String fileName,
    required DocType docType,
    String? transactionId,
    String? ocrText,
    int pageCount,
    ScanStatus scanStatus,
  });

  /// Decrypt and return the original bytes — from the local cache if present,
  /// otherwise downloaded from the remote and then cached.
  Future<Uint8List> load(AttachmentEntity attachment);
}
