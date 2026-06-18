import 'package:drift/drift.dart';

import '../../application/attachment_service.dart';
import '../../application/auth_service.dart';
import '../../domain/entities/attachment.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [AttachmentService]. Owns the synced metadata row only; the
/// encrypted blob is handled separately (Storage + local cache).
class DriftAttachmentService implements AttachmentService {
  DriftAttachmentService(this._db, this._auth);

  final db.AppDatabase _db;
  final AuthService _auth;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) {
      throw StateError('No authenticated user; cannot access attachments.');
    }
    return session.userId;
  }

  @override
  Stream<List<AttachmentEntity>> watchForTransaction(String transactionId) =>
      _db
          .watchAttachments(transactionId)
          .map((rows) => rows.map(_toEntity).toList(growable: false));

  @override
  Future<void> upsert(AttachmentEntity a) {
    final now = DateTime.now().toUtc();
    return _db.upsertAttachment(
      db.AttachmentsCompanion.insert(
        id: a.id,
        userId: a.userId.isEmpty ? _userId : a.userId,
        updatedAt: now,
        transactionId: Value(a.transactionId),
        docType: a.docType,
        fileName: a.fileName,
        storageKey: Value(a.storageKey),
        localCachePath: Value(a.localCachePath),
        encNonce: Value(a.encNonce),
        sha256: a.sha256,
        ocrText: Value(a.ocrText),
        scanStatus: Value(a.scanStatus),
        pageCount: Value(a.pageCount),
        importedAt: a.importedAt,
        deleted: Value(a.deleted),
        version: Value(a.version + 1),
      ),
    );
  }

  @override
  Future<void> delete(String id) =>
      _db.softDeleteAttachment(id, DateTime.now().toUtc());

  AttachmentEntity _toEntity(db.AttachmentRow r) => AttachmentEntity(
        id: r.id,
        userId: r.userId,
        transactionId: r.transactionId,
        docType: r.docType,
        fileName: r.fileName,
        storageKey: r.storageKey,
        localCachePath: r.localCachePath,
        encNonce: r.encNonce,
        sha256: r.sha256,
        ocrText: r.ocrText,
        scanStatus: r.scanStatus,
        pageCount: r.pageCount,
        importedAt: r.importedAt,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );
}
