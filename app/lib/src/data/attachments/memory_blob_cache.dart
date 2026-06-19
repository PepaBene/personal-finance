import 'dart:typed_data';

import '../../application/attachment_store.dart';

/// In-memory [BlobCache]. Works on every platform (including web) and is the
/// default until a persistent native/OPFS cache lands; encrypted bytes only.
class MemoryBlobCache implements BlobCache {
  final _store = <String, Uint8List>{};

  @override
  Future<bool> contains(String key) async => _store.containsKey(key);

  @override
  Future<Uint8List?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, Uint8List bytes) async => _store[key] = bytes;

  @override
  Future<void> remove(String key) async => _store.remove(key);
}
