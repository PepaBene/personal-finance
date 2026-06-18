import 'package:flutter/material.dart';

/// Curated, color-blind-aware categorical palette (>= 12 distinct hues) — the
/// single source of truth used across chips, pickers, and every chart (docs/12
/// §3.2, P9). Held as a [ThemeExtension], never derived from dynamic color.
@immutable
class CategoryColors extends ThemeExtension<CategoryColors> {
  const CategoryColors(this.swatches);

  final List<Color> swatches;

  /// Deterministic color for a category by its stable index/hash.
  Color forIndex(int index) => swatches[index % swatches.length];

  static const CategoryColors palette = CategoryColors([
    Color(0xFF4E79A7),
    Color(0xFFF28E2B),
    Color(0xFFE15759),
    Color(0xFF76B7B2),
    Color(0xFF59A14F),
    Color(0xFFEDC948),
    Color(0xFFB07AA1),
    Color(0xFFFF9DA7),
    Color(0xFF9C755F),
    Color(0xFFBAB0AC),
    Color(0xFF2E91E5),
    Color(0xFF1CA71C),
  ]);

  @override
  CategoryColors copyWith({List<Color>? swatches}) =>
      CategoryColors(swatches ?? this.swatches);

  @override
  CategoryColors lerp(ThemeExtension<CategoryColors>? other, double t) {
    if (other is! CategoryColors || other.swatches.length != swatches.length) {
      return this;
    }
    return CategoryColors(<Color>[
      for (var i = 0; i < swatches.length; i++)
        Color.lerp(swatches[i], other.swatches[i], t)!,
    ]);
  }
}
