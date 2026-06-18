import 'dart:convert';
import 'dart:typed_data';

import '../../application/attachment_cipher.dart';
import '../../application/attachment_store.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/enums.dart';

/// Default [AttachmentStore]: client-side AES-256-GCM (docs/09 §2/§3) over an
/// injected [BlobCache] (local, offline) and [RemoteBlobStore] (Supabase
/// Storage). The cipher, ids and clock are injected so the orchestration is
/// fully unit-testable without a filesystem or backend.
class DefaultAttachmentStore implements AttachmentStore {
  DefaultAttachmentStore({
    required AttachmentCipher cipher,
    required BlobCache cache,
    required RemoteBlobStore remote,
    required String Function() userId,
    required String Function() newId,
    required DateTime Function() now,
  })  : _cipher = cipher,
        _cache = cache,
        _remote = remote,
        _userId = userId,
        _newId = newId,
        _now = now;

  final AttachmentCipher _cipher;
  final BlobCache _cache;
  final RemoteBlobStore _remote;
  final String Function() _userId;
  final String Function() _newId;
  final DateTime Function() _now;

  @override
  Future<AttachmentEntity> save({
    required Uint8List bytes,
    required String fileName,
    required DocType docType,
    String? transactionId,
    String? ocrText,
    int pageCount = 1,
    ScanStatus scanStatus = ScanStatus.reviewed,
  }) async {
    final userId = _userId();
    final blob = await _cipher.encrypt(bytes);
    final id = _newId();

    // Per-user object path; sha256 of the plaintext dedupes identical files.
    final storageKey = '$userId/${blob.sha256Hex}';
    await _cache.write(id, blob.storageBytes);
    if (_remote.isAvailable) {
      await _remote.upload(storageKey, blob.storageBytes);
    }

    final at = _now();
    return AttachmentEntity(
      id: id,
      userId: userId,
      transactionId: transactionId,
      docType: docType,
      fileName: fileName,
      storageKey: _remote.isAvailable ? storageKey : null,
      localCachePath: id,
      encNonce: blob.nonceBase64,
      sha256: blob.sha256Hex,
      ocrText: ocrText,
      scanStatus: scanStatus,
      pageCount: pageCount,
      importedAt: at,
      updatedAt: at,
    );
  }

  @override
  Future<Uint8List> load(AttachmentEntity attachment) async {
    final nonceB64 = attachment.encNonce;
    if (nonceB64 == null) {
      throw StateError('Attachment ${attachment.id} has no encryption nonce.');
    }
    final nonce = base64Decode(nonceB64);
    final cacheKey = attachment.localCachePath ?? attachment.id;

    final cached = await _cache.read(cacheKey);
    if (cached != null) {
      return _cipher.decrypt(nonce: nonce, storageBytes: cached);
    }

    final key = attachment.storageKey;
    if (key == null || !_remote.isAvailable) {
      throw StateError('Attachment ${attachment.id} blob is unavailable.');
    }
    final downloaded = await _remote.download(key);
    await _cache.write(cacheKey, downloaded);
    return _cipher.decrypt(nonce: nonce, storageBytes: downloaded);
  }
}
