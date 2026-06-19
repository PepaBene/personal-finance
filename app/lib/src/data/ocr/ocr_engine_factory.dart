// Selects the on-device OCR engine for the current platform via conditional
// imports (docs/05 §3). On web we use the browser Shape Detection API; on other
// platforms no engine is bundled yet (ML Kit / Apple Vision / Tesseract are the
// drop-in follow-ups), so `createOcrEngine` returns null and the scan flow falls
// back to manual entry (docs/05 §6).
export 'ocr_engine_factory_stub.dart'
    if (dart.library.js_interop) 'ocr_engine_factory_web.dart';
