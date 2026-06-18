import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/data/attachments/file_blob_cache.dart';

void main() {
  late Directory dir;
  late FileBlobCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ledgerly_blobcache_');
    cache = FileBlobCache(Directory('${dir.path}/cache'));
  });
  tearDown(() => dir.delete(recursive: true));

  test('write/read/contains/remove round-trip', () async {
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));
    expect(await cache.contains('a1'), isFalse);
    expect(await cache.read('a1'), isNull);

    await cache.write('a1', bytes);
    expect(await cache.contains('a1'), isTrue);
    expect(await cache.read('a1'), bytes);

    await cache.remove('a1');
    expect(await cache.contains('a1'), isFalse);
    expect(await cache.read('a1'), isNull);
  });

  test('creates the cache directory on first write', () async {
    expect(Directory('${dir.path}/cache').existsSync(), isFalse);
    await cache.write('k', Uint8List.fromList([1, 2, 3]));
    expect(Directory('${dir.path}/cache').existsSync(), isTrue);
  });
}
