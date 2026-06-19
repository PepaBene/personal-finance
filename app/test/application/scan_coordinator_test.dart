import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/ocr_engine.dart';
import 'package:ledgerly_app/src/application/scan_coordinator.dart';
import 'package:ledgerly_app/src/application/scan_ingest.dart';
import 'package:ledgerly_app/src/application/scan_service.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/scan/document_draft.dart';

class _FakeIngest implements ScanIngest {
  _FakeIngest(this._doc);
  final IngestedDocument? _doc;
  @override
  bool supports(ScanSource source) => true;
  @override
  Future<IngestedDocument?> pick(ScanSource source) async => _doc;
}

class _FakeScanService implements ScanService {
  _FakeScanService(this._draft, {this.throws = false});
  final DocumentDraft _draft;
  final bool throws;
  @override
  Stream<ScanProgress> get progress => const Stream.empty();
  @override
  Future<DocumentDraft> scan(ScanInput input,
      {CancellationToken? token}) async {
    if (throws) throw StateError('ocr failed');
    return _draft;
  }
}

IngestedDocument _doc() => IngestedDocument(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'r.jpg',
      source: ScanSource.imageFile,
    );

DocumentDraft _parsed() => DocumentDraft(
      type: DocType.receipt,
      merchant: 'Albert',
      total: Decimal.parse('10.00'),
    );

void main() {
  test('returns null when the user cancels the picker', () async {
    final c = ScanCoordinator(ingest: _FakeIngest(null));
    expect(await c.capture(ScanSource.imageFile), isNull);
  });

  test('runs the pipeline and returns the parsed draft when an engine exists',
      () async {
    final c = ScanCoordinator(
      ingest: _FakeIngest(_doc()),
      scanService: _FakeScanService(_parsed()),
    );
    final result = await c.capture(ScanSource.imageFile);
    expect(c.hasOcr, isTrue);
    expect(result!.usedOcr, isTrue);
    expect(result.draft.merchant, 'Albert');
    expect(result.imageBytes, Uint8List.fromList([1, 2, 3]));
  });

  test('falls back to a blank draft when no engine is wired', () async {
    final c = ScanCoordinator(ingest: _FakeIngest(_doc()));
    final result = await c.capture(ScanSource.imageFile);
    expect(c.hasOcr, isFalse);
    expect(result!.usedOcr, isFalse);
    expect(result.draft.type, DocType.receipt);
    expect(result.draft.merchant, isNull);
    expect(
        result.imageBytes, isNotEmpty); // image still attached for manual entry
  });

  test('degrades to manual entry when OCR throws', () async {
    final c = ScanCoordinator(
      ingest: _FakeIngest(_doc()),
      scanService: _FakeScanService(_parsed(), throws: true),
    );
    final result = await c.capture(ScanSource.imageFile);
    expect(result!.usedOcr, isFalse);
    expect(result.draft.merchant, isNull);
    expect(result.imageBytes, isNotEmpty);
  });
}
