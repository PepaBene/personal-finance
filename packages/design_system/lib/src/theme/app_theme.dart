import 'package:flutter/material.dart';

import '../tokens/category_colors.dart';
import '../tokens/motion.dart';
import '../tokens/radii.dart';
import '../tokens/semantic_colors.dart';
import '../tokens/spacing.dart';

/// Builds the Ledgerly Material 3 themes from a single seed plus the token
/// [ThemeExtension]s. Light and dark share token *names*; only values differ
/// (docs/12 §5). High-contrast is produced via [ColorScheme.fromSeed]'s
/// `contrastLevel`.
abstract final class AppTheme {
  /// Fixed Ledgerly brand seed (dynamic color may override on Android 12+).
  static const Color seed = Color(0xFF2E7D6B);

  static ThemeData light({double contrastLevel = 0}) =>
      _build(Brightness.light, SemanticColors.light, contrastLevel);

  static ThemeData dark({double contrastLevel = 0}) =>
      _build(Brightness.dark, SemanticColors.dark, contrastLevel);

  static ThemeData _build(
    Brightness brightness,
    SemanticColors semantic,
    double contrastLevel,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );
    const radii = AppRadii();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[
        const AppSpacing(),
        radii,
        const AppMotion(),
        CategoryColors.palette,
        semantic,
      ],
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radii.lgRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radii.mdRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radii.mdRadius),
        filled: true,
      ),
    );
  }
}

/// Token accessors on [BuildContext] so widgets read tokens, not literals.
extension AppTokens on BuildContext {
  AppSpacing get space => Theme.of(this).extension<AppSpacing>()!;
  AppRadii get radii => Theme.of(this).extension<AppRadii>()!;
  AppMotion get motion => Theme.of(this).extension<AppMotion>()!;
  SemanticColors get semantic => Theme.of(this).extension<SemanticColors>()!;
  CategoryColors get categoryColors =>
      Theme.of(this).extension<CategoryColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}
