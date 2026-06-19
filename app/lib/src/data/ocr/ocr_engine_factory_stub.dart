import '../../application/ocr_engine.dart';

/// Default: no bundled on-device engine yet on this platform. The scan flow
/// detects null and routes to manual entry / cloud fallback (docs/05 §6). Mobile
/// ML Kit, Apple Vision, and desktop Tesseract are the drop-in replacements here.
OcrEngine? createOcrEngine() => null;
