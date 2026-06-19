import 'package:freezed_annotation/freezed_annotation.dart';

part 'ocr_result.freezed.dart';

/// Normalized bounding box (0..1 in both axes) so boxes map across rasterization
/// resolutions (docs/05 §3). Origin top-left.
@freezed
abstract class OcrBox with _$OcrBox {
  const factory OcrBox({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) = _OcrBox;
  const OcrBox._();

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
  double get width => right - left;
}

@freezed
abstract class OcrWord with _$OcrWord {
  const factory OcrWord({
    required String text,
    required OcrBox box,
    @Default(1.0) double confidence,
  }) = _OcrWord;
}

@freezed
abstract class OcrLine with _$OcrLine {
  const factory OcrLine({
    required String text,
    @Default(<OcrWord>[]) List<OcrWord> words,
  }) = _OcrLine;
}

/// Engine-agnostic OCR output: text with geometry + confidence (docs/05 §3).
@freezed
abstract class OcrResult with _$OcrResult {
  const factory OcrResult({
    required String fullText,
    @Default(<OcrLine>[]) List<OcrLine> lines,
    @Default('unknown') String engineId,
    @Default(Duration.zero) Duration elapsed,
  }) = _OcrResult;
  const OcrResult._();

  Iterable<OcrWord> get allWords => lines.expand((l) => l.words);
}
