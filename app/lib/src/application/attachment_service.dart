import '../domain/entities/attachment.dart';

/// CRUD for attachment metadata (docs/04 §2.6, FR-SCAN-08). The encrypted blob
/// bytes live in Supabase Storage (via an AttachmentStore, later increment); this
/// service owns only the synced DB row — metadata, OCR text, integrity hash, and
/// the AES-256-GCM nonce. Implemented by a Drift adapter.
abstract interface class AttachmentService {
  /// Attachments linked to [transactionId], newest first.
  Stream<List<AttachmentEntity>> watchForTransaction(String transactionId);

  Future<void> upsert(AttachmentEntity attachment);

  /// Soft-delete (tombstone) so the removal converges across devices.
  Future<void> delete(String id);
}
