import 'dart:typed_data';

import '../../application/attachment_store.dart';

/// Offline [RemoteBlobStore] used when no cloud is configured (FR-SYNC-01).
/// Attachments stay in the local cache only; uploads are no-ops and downloads
/// are never attempted ([isAvailable] is false).
class NullRemoteBlobStore implements RemoteBlobStore {
  const NullRemoteBlobStore();

  @override
  bool get isAvailable => false;

  @override
  Future<void> upload(String key, Uint8List bytes) async {}

  @override
  Future<Uint8List> download(String key) =>
      throw StateError('No remote blob store configured.');

  @override
  Future<void> remove(String key) async {}
}
