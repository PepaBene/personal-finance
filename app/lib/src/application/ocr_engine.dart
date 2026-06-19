import 'dart:typed_data';

import '../domain/scan/ocr_result.dart';

/// Image handed to an [OcrEngine] (preprocessed bitmap bytes).
class OcrImage {
  const OcrImage(this.bytes, {this.width, this.height});
  final Uint8List bytes;
  final int? width;
  final int? height;
}

/// Recognition options (languages default to the user profile: CS + EN).
class OcrOptions {
  const OcrOptions({this.languages = const ['en', 'cs']});
  final List<String> languages;
}

/// Cooperative cancellation for long-running OCR (docs/05 §5).
class CancellationToken {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;

  /// Throw [ScanCancelled] if cancellation has been requested.
  void throwIfCancelled() {
    if (_cancelled) throw const ScanCancelled();
  }
}

/// Thrown by the OCR pipeline when a [CancellationToken] has been cancelled, so
/// callers can distinguish a user-cancelled scan from a genuine failure.
class ScanCancelled implements Exception {
  const ScanCancelled();
  @override
  String toString() => 'ScanCancelled';
}

/// Engine-agnostic OCR port (docs/05 §3). Implementations are platform-adaptive
/// (ML Kit / Apple Vision / Tesseract / Tesseract.js) and bound at the
/// composition root, so the parsing pipeline never depends on a specific engine.
abstract interface class OcrEngine {
  /// Engine id for logging/metrics ('mlkit', 'vision', 'tesseract', …).
  String get id;
  List<String> get supportedLanguages;

  /// True if recognition runs entirely on-device / in-browser (privacy).
  bool get isOnDevice;

  Future<OcrResult> recognize(
    OcrImage image, {
    OcrOptions options = const OcrOptions(),
    CancellationToken? token,
  });
}

/// Selects the right [OcrEngine] per platform; optional opt-in cloud fallback.
abstract interface class OcrEngineFactory {
  OcrEngine forCurrentPlatform(OcrOptions options);
  OcrEngine? cloudFallback(OcrOptions options);
}
