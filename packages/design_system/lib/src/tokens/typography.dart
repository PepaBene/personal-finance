import 'package:flutter/material.dart';

/// Brand typography (docs/12 §5). Pairs a characterful display serif
/// ([displayFamily] — Fraunces) for headlines and large money figures with a
/// clean grotesque ([sansFamily] — Geist) for everything else. Both are
/// *variable* fonts shipped as a single asset per family; weight is selected via
/// the `wght` axis and Fraunces' optical size via `opsz`, so any weight is
/// available without bundling a file per weight.
///
/// The returned [TextTheme] carries no colours — [ThemeData] applies the
/// scheme's `onSurface`/`onSurfaceVariant` so light and dark share one type
/// ramp. Money uses tabular figures via [MoneyText]; see [moneyStyle].
abstract final class AppTypography {
  static const String displayFamily = 'Fraunces';
  static const String sansFamily = 'Geist';

  /// Maps a continuous `wght` axis value to the nearest [FontWeight] bucket so
  /// layout, accessibility, and any non-variable fallback stay coherent.
  static FontWeight _bucket(double wght) {
    final steps = <double, FontWeight>{
      100: FontWeight.w100,
      200: FontWeight.w200,
      300: FontWeight.w300,
      400: FontWeight.w400,
      500: FontWeight.w500,
      600: FontWeight.w600,
      700: FontWeight.w700,
      800: FontWeight.w800,
      900: FontWeight.w900,
    };
    final key = (wght / 100).round() * 100.0;
    return steps[key.clamp(100, 900)] ?? FontWeight.w400;
  }

  /// A Geist (grotesque) style. [tabular] enables tabular figures for aligned
  /// numerals (money, tables).
  static TextStyle sans(
    double size, {
    double wght = 400,
    double? height,
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: _bucket(wght),
      fontVariations: [FontVariation('wght', wght)],
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// A Fraunces (display serif) style. [opsz] follows the optical-size axis
  /// (9–144); defaults to the point size so large text gets the high-contrast
  /// display cut and small text stays readable.
  static TextStyle display(
    double size, {
    double wght = 580,
    double? height,
    double letterSpacing = 0,
    double? opsz,
  }) {
    final optical = (opsz ?? size).clamp(9.0, 144.0);
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: _bucket(wght),
      fontVariations: [
        FontVariation('wght', wght),
        FontVariation('opsz', optical),
      ],
    );
  }

  /// Tabular money style at an arbitrary size — used by `MoneyText` so amounts
  /// line up and never reflow. [display] swaps Geist for the Fraunces serif
  /// (the hero balance); otherwise numerals use Geist for crisp alignment.
  static TextStyle moneyStyle(
    double size, {
    double wght = 600,
    bool useDisplay = false,
    double? height,
  }) {
    if (useDisplay) {
      return display(size, wght: wght, height: height)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    }
    return sans(size, wght: wght, height: height, tabular: true);
  }

  /// The full Material 3 type ramp, retuned for the "refined & calm" look:
  /// display/headline in Fraunces with tight tracking; titles/body/labels in
  /// Geist. Sizes track M3 defaults so existing `context.texts.*` call sites
  /// keep working.
  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: display(57, wght: 560, height: 1.05, letterSpacing: -1.0),
      displayMedium: display(45, wght: 560, height: 1.08, letterSpacing: -0.5),
      displaySmall: display(36, wght: 580, height: 1.12, letterSpacing: -0.25),
      headlineLarge: display(32, wght: 580, height: 1.15, letterSpacing: -0.25),
      headlineMedium: display(28, wght: 600, height: 1.18),
      headlineSmall: display(24, wght: 600, height: 1.2),
      titleLarge: sans(22, wght: 600, height: 1.25, letterSpacing: -0.2),
      titleMedium: sans(16, wght: 600, height: 1.3, letterSpacing: 0.1),
      titleSmall: sans(14, wght: 600, height: 1.35, letterSpacing: 0.1),
      bodyLarge: sans(16, wght: 400, height: 1.45),
      bodyMedium: sans(14, wght: 400, height: 1.45),
      bodySmall: sans(12, wght: 400, height: 1.4, letterSpacing: 0.2),
      labelLarge: sans(14, wght: 600, height: 1.2, letterSpacing: 0.1),
      labelMedium: sans(12, wght: 600, height: 1.2, letterSpacing: 0.4),
      labelSmall: sans(11, wght: 600, height: 1.2, letterSpacing: 0.5),
    );
  }
}
