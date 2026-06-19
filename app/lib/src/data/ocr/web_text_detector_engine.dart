import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../application/ocr_engine.dart';
import '../../domain/scan/ocr_result.dart';

/// Browser **Shape Detection API** binding (`TextDetector`).
@JS('TextDetector')
extension type _TextDetector._(JSObject _) implements JSObject {
  external factory _TextDetector();
  external JSPromise<JSArray<_DetectedText>> detect(JSAny image);
}

extension type _DetectedText._(JSObject _) implements JSObject {
  external String get rawValue;
  external web.DOMRectReadOnly get boundingBox;
}

/// On-device web OCR via the browser Shape Detection API (docs/05 §3). Detects
/// text blocks with bounding boxes; we split each block into words with
/// proportional boxes so the parser's layout reconstruction (§5) can run. No
/// per-word confidence is exposed by the API, so a neutral 0.5 is used.
class WebTextDetectorEngine implements OcrEngine {
  const WebTextDetectorEngine();

  @override
  String get id => 'web_text_detector';

  @override
  List<String> get supportedLanguages => const ['en', 'cs'];

  @override
  bool get isOnDevice => true;

  @override
  Future<OcrResult> recognize(
    OcrImage image, {
    OcrOptions options = const OcrOptions(),
    CancellationToken? token,
  }) async {
    final sw = Stopwatch()..start();
    final blob = web.Blob(
      [image.bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/*'),
    );
    final bitmap = await web.window.createImageBitmap(blob).toDart;
    final w = bitmap.width.toDouble();
    final h = bitmap.height.toDouble();

    final detected =
        (await _TextDetector().detect(bitmap as JSAny).toDart).toDart;

    final lines = <OcrLine>[];
    final full = StringBuffer();
    for (final d in detected) {
      final text = d.rawValue.trim();
      if (text.isEmpty) continue;
      full.writeln(text);
      final r = d.boundingBox;
      lines.add(
        _line(text, r.x / w, r.y / h, r.width / w, r.height / h),
      );
    }
    sw.stop();
    return OcrResult(
      engineId: id,
      fullText: full.toString().trimRight(),
      lines: lines,
      elapsed: sw.elapsed,
    );
  }

  OcrLine _line(
    String text,
    double left,
    double top,
    double width,
    double height,
  ) {
    final tokens =
        text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return OcrLine(text: text, words: const []);
    final totalChars = tokens.fold<int>(0, (s, t) => s + t.length);
    final words = <OcrWord>[];
    var cursor = left;
    for (final tok in tokens) {
      final frac =
          totalChars == 0 ? 1 / tokens.length : tok.length / totalChars;
      final wWidth = width * frac;
      words.add(
        OcrWord(
          text: tok,
          box: OcrBox(
            left: cursor,
            top: top,
            right: cursor + wWidth,
            bottom: top + height,
          ),
          confidence: 0.5,
        ),
      );
      cursor += wWidth;
    }
    return OcrLine(text: text, words: words);
  }
}
