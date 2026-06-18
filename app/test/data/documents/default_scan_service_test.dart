import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/document_parser.dart';
import 'package:ledgerly_app/src/application/ocr_engine.dart';
import 'package:ledgerly_app/src/application/scan_service.dart';
import 'package:ledgerly_app/src/data/documents/default_scan_service.dart';
import 'package:ledgerly_app/src/data/documents/keyword_document_classifier.dart';
import 'package:ledgerly_app/src/data/documents/receipt_parser.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/scan/ocr_result.dart';

class _FakeEngine implements OcrEngine {
  _FakeEngine(this._result);
  final OcrResult _result;
  @override
  String get id => 'fake';
  @override
  List<String> get supportedLanguages => const ['en', 'cs'];
  @override
  bool get isOnDevice => true;
  @override
  Future<OcrResult> recognize(OcrImage image,
          {OcrOptions options = const OcrOptions(),
          CancellationToken? token}) async =>
      _result;
}

OcrWord _w(String t, double x, double y) => OcrWord(
      text: t,
      box: OcrBox(
          left: x - 0.05, top: y - 0.01, right: x + 0.05, bottom: y + 0.01),
    );

void main() {
  test('orchestrates OCR -> classify -> parse into a draft', () async {
    final ocr = OcrResult(
      engineId: 'fake',
      fullText: 'TESCO\nApple 19,90\nCELKEM 19,90\nKč',
      lines: [
        OcrLine(text: 'TESCO', words: [_w('TESCO', 0.2, 0.05)]),
        OcrLine(
            text: 'Apple 19,90',
            words: [_w('Apple', 0.15, 0.2), _w('19,90', 0.85, 0.2)]),
        OcrLine(
            text: 'CELKEM 19,90',
            words: [_w('CELKEM', 0.15, 0.4), _w('19,90', 0.85, 0.4)]),
        OcrLine(text: 'Kč', words: [_w('Kč', 0.5, 0.6)]),
      ],
    );

    final service = DefaultScanService(
      engine: _FakeEngine(ocr),
      classifier: const KeywordDocumentClassifier(),
      parsers: const {DocType.receipt: ReceiptParser()},
      contextBuilder: () => const ParseContext(defaultCurrencyCode: 'EUR'),
    );
    addTearDown(service.dispose);

    final progress = <String>[];
    service.progress.listen((p) => progress.add(p.stage));

    final draft = await service.scan(
      ScanInput(OcrImage(Uint8List(0))),
    );

    expect(draft.type, DocType.receipt);
    expect(draft.merchant, 'TESCO');
    expect(draft.total, Decimal.parse('19.90'));
    expect(draft.currencyCode, 'CZK');
    expect(draft.lineItems.single.description, 'Apple');
    await Future<void>.delayed(Duration.zero);
    expect(progress, containsAllInOrder(['ocr', 'classify', 'parse', 'done']));
  });
}
