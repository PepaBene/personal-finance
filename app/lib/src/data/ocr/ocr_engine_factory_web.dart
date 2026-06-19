import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../application/ocr_engine.dart';
import 'web_text_detector_engine.dart';

/// Web: use the browser **Shape Detection API** (`TextDetector`) when present
/// (docs/05 §3, on-device/in-browser). Returns null where unsupported so the
/// flow falls back to manual entry; Tesseract.js (WASM) is the heavier fallback.
OcrEngine? createOcrEngine() =>
    globalContext.has('TextDetector') ? const WebTextDetectorEngine() : null;
