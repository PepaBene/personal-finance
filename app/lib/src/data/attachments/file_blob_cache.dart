import 'dart:io';
import 'dart:typed_data';

import '../../application/attachment_store.dart';

/// Filesystem [BlobCache] for native platforms (docs/05 §5): encrypted blob
/// bytes are written under a per-app cache directory, one `.enc` file per
/// attachment id. Not used on web (no `dart:io`); see [MemoryBlobCache].
class FileBlobCache implements BlobCache {
  FileBlobCache(this._dir);

  final Directory _dir;

  File _file(String key) => File('${_dir.path}/$key.enc');

  @override
  Future<bool> contains(String key) => _file(key).exists();

  @override
  Future<Uint8List?> read(String key) async {
    final f = _file(key);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    await _dir.create(recursive: true);
    await _file(key).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> remove(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }
}
