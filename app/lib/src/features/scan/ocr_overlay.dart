import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/scan/ocr_result.dart';

/// The original document with OCR bounding-box overlays (docs/06 §2.5). Boxes are
/// normalized (0..1) so they map onto the rendered image at any size; the image
/// is drawn with [BoxFit.fill] to keep that mapping exact. Words matching
/// [highlight] (the currently-selected field's text) are drawn emphasized.
class OcrOverlay extends StatelessWidget {
  const OcrOverlay({
    required this.ocr,
    required this.imageBytes,
    this.highlight,
    super.key,
  });

  final OcrResult ocr;
  final Uint8List imageBytes;

  /// Lowercased text whose source words should be highlighted, or null.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    final box = context.colors.outline;
    return ClipRRect(
      borderRadius: context.radii.mdRadius,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(imageBytes, fit: BoxFit.fill),
            CustomPaint(
              painter: _OcrBoxPainter(
                words: ocr.allWords.toList(),
                highlight: highlight,
                boxColor: box,
                accentColor: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrBoxPainter extends CustomPainter {
  _OcrBoxPainter({
    required this.words,
    required this.highlight,
    required this.boxColor,
    required this.accentColor,
  });

  final List<OcrWord> words;
  final String? highlight;
  final Color boxColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = boxColor.withValues(alpha: 0.5);
    final hit = highlight?.toLowerCase();

    for (final w in words) {
      final rect = Rect.fromLTRB(
        w.box.left * size.width,
        w.box.top * size.height,
        w.box.right * size.width,
        w.box.bottom * size.height,
      );
      final isHit =
          hit != null && hit.isNotEmpty && w.text.toLowerCase().contains(hit);
      if (isHit) {
        canvas.drawRect(
          rect,
          Paint()..color = accentColor.withValues(alpha: 0.25),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = accentColor,
        );
      } else {
        canvas.drawRect(rect, base);
      }
    }
  }

  @override
  bool shouldRepaint(_OcrBoxPainter old) =>
      old.highlight != highlight || old.words != words;
}
