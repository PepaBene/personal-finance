import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';

part 'attachment.freezed.dart';

/// A scanned/imported document (docs/04 §2.6). The blob bytes are **not** stored
/// here — they live as a client-side-encrypted object in Supabase Storage
/// ([storageKey]) with a local cache ([localCachePath]). This row keeps the
/// metadata, OCR text (searchable), the integrity hash, and the GCM nonce needed
/// to decrypt the blob. Carries sync columns (FR-SYNC-03).
@freezed
abstract class AttachmentEntity with _$AttachmentEntity {
  const factory AttachmentEntity({
    required String id,
    required String userId,
    String? transactionId,
    required DocType docType,
    required String fileName,
    String? storageKey,
    String? localCachePath,

    /// Base64 AES-256-GCM nonce/IV for the client-side-encrypted blob (docs/09 §2).
    String? encNonce,

    /// Lowercase hex SHA-256 of the plaintext — dedupe + integrity (docs/09 §7).
    required String sha256,

    /// Full extracted text, persisted for full-text search (FR-SCAN-08).
    String? ocrText,
    @Default(ScanStatus.pending) ScanStatus scanStatus,
    @Default(1) int pageCount,
    required DateTime importedAt,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _AttachmentEntity;

  const AttachmentEntity._();

  bool get isUploaded => storageKey != null;
}
