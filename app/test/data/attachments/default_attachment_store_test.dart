import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/attachment_store.dart';
import 'package:ledgerly_app/src/data/attachments/default_attachment_store.dart';
import 'package:ledgerly_app/src/data/attachments/memory_blob_cache.dart';
import 'package:ledgerly_app/src/data/crypto/aes_gcm_attachment_cipher.dart';
import 'package:ledgerly_app/src/domain/enums.dart';

/// In-memory remote that records uploads, so we can test the download path.
class _FakeRemote implements RemoteBlobStore {
  final store = <String, Uint8List>{};
  @override
  bool get isAvailable => true;
  @override
  Future<void> upload(String key, Uint8List bytes) async => store[key] = bytes;
  @override
  Future<Uint8List> download(String key) async =>
      store[key] ?? (throw StateError('missing $key'));
  @override
  Future<void> remove(String key) async => store.remove(key);
}

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  final cipher = AesGcmAttachmentCipher(SecretKey(List<int>.filled(32, 3)));
  var n = 0;

  DefaultAttachmentStore store(
    BlobCache cache,
    RemoteBlobStore remote,
  ) {
    n = 0;
    return DefaultAttachmentStore(
      cipher: cipher,
      cache: cache,
      remote: remote,
      userId: () => 'u1',
      newId: () => 'att${n++}',
      now: () => DateTime.utc(2026, 6, 18),
    );
  }

  test('save encrypts, caches, uploads, and returns metadata', () async {
    final cache = MemoryBlobCache();
    final remote = _FakeRemote();
    final plain = _bytes('receipt bytes');

    final att = await store(cache, remote).save(
      bytes: plain,
      fileName: 'albert.jpg',
      docType: DocType.receipt,
      transactionId: 'tx1',
      ocrText: 'ALBERT',
    );

    expect(att.fileName, 'albert.jpg');
    expect(att.transactionId, 'tx1');
    expect(att.encNonce, isNotNull);
    expect(att.sha256, hasLength(64));
    expect(att.storageKey, 'u1/${att.sha256}');
    expect(att.scanStatus, ScanStatus.reviewed);

    // Stored bytes are ciphertext, not the plaintext.
    final cached = await cache.read(att.localCachePath!);
    expect(cached, isNotNull);
    expect(cached, isNot(plain));
    expect(remote.store[att.storageKey], cached);
  });

  test('round-trips bytes through save then load (from cache)', () async {
    final cache = MemoryBlobCache();
    final remote = _FakeRemote();
    final s = store(cache, remote);
    final plain = _bytes('hello receipt');

    final att = await s.save(
      bytes: plain,
      fileName: 'f.jpg',
      docType: DocType.receipt,
    );
    expect(await s.load(att), plain);
  });

  test('loads from the remote on a cache miss, then re-caches', () async {
    final remote = _FakeRemote();
    final plain = _bytes('cloud only');
    final att = await store(MemoryBlobCache(), remote).save(
      bytes: plain,
      fileName: 'f.jpg',
      docType: DocType.invoice,
    );

    // Fresh device: empty cache, same remote + cipher.
    final freshCache = MemoryBlobCache();
    final fresh = store(freshCache, remote);
    expect(await freshCache.contains(att.localCachePath!), isFalse);

    expect(await fresh.load(att), plain);
    // Downloaded blob is now cached locally.
    expect(await freshCache.contains(att.localCachePath!), isTrue);
  });

  test('offline (no remote) keeps the blob in the local cache only', () async {
    final cache = MemoryBlobCache();
    final s = store(cache, const _OfflineRemote());
    final att = await s.save(
      bytes: _bytes('offline'),
      fileName: 'f.jpg',
      docType: DocType.receipt,
    );
    expect(att.storageKey, isNull); // nothing uploaded
    expect(await s.load(att), _bytes('offline')); // still loadable locally
  });

  test('load throws when the blob is gone and there is no remote', () async {
    final s = store(MemoryBlobCache(), const _OfflineRemote());
    final att = await s.save(
      bytes: _bytes('x'),
      fileName: 'f.jpg',
      docType: DocType.receipt,
    );
    // Simulate cache eviction by loading a copy whose cache key is absent.
    final orphan = att.copyWith(localCachePath: 'missing', storageKey: null);
    expect(() => s.load(orphan), throwsStateError);
  });
}

class _OfflineRemote implements RemoteBlobStore {
  const _OfflineRemote();
  @override
  bool get isAvailable => false;
  @override
  Future<void> upload(String key, Uint8List bytes) async {}
  @override
  Future<Uint8List> download(String key) => throw StateError('offline');
  @override
  Future<void> remove(String key) async {}
}
