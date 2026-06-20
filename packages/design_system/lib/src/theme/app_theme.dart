import 'package:flutter/material.dart';

import '../tokens/category_colors.dart';
import '../tokens/elevation.dart';
import '../tokens/gradients.dart';
import '../tokens/motion.dart';
import '../tokens/radii.dart';
import '../tokens/semantic_colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Builds the Ledgerly Material 3 themes — a "refined & calm" finance aesthetic
/// (premium minimalism: warm neutrals, a confident teal, big serif numerals,
/// soft depth). Light and dark share token *names* and the type ramp; only
/// values differ (docs/12 §5). High-contrast is produced via
/// [ColorScheme.fromSeed]'s `contrastLevel`.
abstract final class AppTheme {
  /// Fixed Ledgerly brand seed (dynamic color may override on Android 12+).
  static const Color seed = Color(0xFF2E7D6B);

  static ThemeData light({double contrastLevel = 0}) => _build(
        Brightness.light,
        SemanticColors.light,
        AppElevation.light,
        AppGradients.light,
        _LightSurfaces(),
        contrastLevel,
      );

  static ThemeData dark({double contrastLevel = 0}) => _build(
        Brightness.dark,
        SemanticColors.dark,
        AppElevation.dark,
        AppGradients.dark,
        _DarkSurfaces(),
        contrastLevel,
      );

  static ThemeData _build(
    Brightness brightness,
    SemanticColors semantic,
    AppElevation elevation,
    AppGradients gradients,
    _Surfaces s,
    double contrastLevel,
  ) {
    // Seed the roles (primary/secondary/error + their `on*`), then override the
    // neutral surface family with our warmer, intentionally-tuned values so the
    // app doesn't read as a stock M3 sample.
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      contrastLevel: contrastLevel,
    ).copyWith(
      surface: s.surface,
      onSurface: s.onSurface,
      onSurfaceVariant: s.onSurfaceVariant,
      surfaceContainerLowest: s.containerLowest,
      surfaceContainerLow: s.containerLow,
      surfaceContainer: s.container,
      surfaceContainerHigh: s.containerHigh,
      surfaceContainerHighest: s.containerHighest,
      surfaceDim: s.dim,
      surfaceBright: s.bright,
      outline: s.outline,
      outlineVariant: s.outlineVariant,
      surfaceTint: Colors.transparent,
    );

    const radii = AppRadii();
    final texts = AppTypography.textTheme();
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      textTheme: texts,
      fontFamily: AppTypography.sansFamily,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[
        const AppSpacing(),
        radii,
        const AppMotion(),
        CategoryColors.palette,
        semantic,
        elevation,
        gradients,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texts.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: s.cardColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radii.lgRadius,
          side: BorderSide(color: s.hairline),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: radii.mdRadius),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        secondarySelectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        side: BorderSide(color: s.hairline),
        labelStyle: texts.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        secondaryLabelStyle:
            texts.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radii.mdRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radii.mdRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radii.mdRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radii.mdRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radii.mdRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: texts.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radii.mdRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 52),
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: texts.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radii.mdRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: texts.labelLarge,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: radii.mdRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: texts.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radii.mdRadius),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(texts.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.secondaryContainer;
            }
            return scheme.surfaceContainerHigh;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onSecondaryContainer;
            }
            return scheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: s.hairline)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radii.pillRadius),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return texts.labelMedium?.copyWith(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color:
                selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme:
            IconThemeData(size: 24, color: scheme.onSecondaryContainer),
        unselectedIconTheme:
            IconThemeData(size: 24, color: scheme.onSurfaceVariant),
        selectedLabelTextStyle:
            texts.labelMedium?.copyWith(color: scheme.onSurface),
        unselectedLabelTextStyle:
            texts.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        useIndicator: true,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radii.lg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radii.lgRadius),
        titleTextStyle: texts.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle:
            texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            texts.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: radii.mdRadius),
        insetPadding: const EdgeInsets.all(16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: isDark ? 0 : 2,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 0,
        extendedTextStyle: texts.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: radii.lgRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: radii.smRadius,
        ),
        textStyle: texts.labelMedium?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}

/// Neutral surface ramp per brightness — warmer and more intentional than the
/// seeded defaults. Kept private; only [AppTheme] consumes it.
abstract class _Surfaces {
  Color get surface;
  Color get onSurface;
  Color get onSurfaceVariant;
  Color get containerLowest;
  Color get containerLow;
  Color get container;
  Color get containerHigh;
  Color get containerHighest;
  Color get dim;
  Color get bright;
  Color get outline;
  Color get outlineVariant;

  /// Resting card fill and its hairline border.
  Color get cardColor;
  Color get hairline;
}

class _LightSurfaces extends _Surfaces {
  @override
  Color get surface => const Color(0xFFFAF9F6); // warm off-white
  @override
  Color get onSurface => const Color(0xFF1A1C1A);
  @override
  Color get onSurfaceVariant => const Color(0xFF53605A);
  @override
  Color get containerLowest => const Color(0xFFFFFFFF);
  @override
  Color get containerLow => const Color(0xFFF5F3EE);
  @override
  Color get container => const Color(0xFFF0EDE6);
  @override
  Color get containerHigh => const Color(0xFFEAE7DF);
  @override
  Color get containerHighest => const Color(0xFFE4E0D7);
  @override
  Color get dim => const Color(0xFFE0DCD3);
  @override
  Color get bright => const Color(0xFFFAF9F6);
  @override
  Color get outline => const Color(0xFFBFC4BD);
  @override
  Color get outlineVariant => const Color(0xFFE2E0D8);
  @override
  Color get cardColor => const Color(0xFFFFFFFF);
  @override
  Color get hairline => const Color(0xFFE6E3DB);
}

class _DarkSurfaces extends _Surfaces {
  @override
  Color get surface => const Color(0xFF0F1311); // near-black, faint teal-warm
  @override
  Color get onSurface => const Color(0xFFE8EBE6);
  @override
  Color get onSurfaceVariant => const Color(0xFFADB5AE);
  @override
  Color get containerLowest => const Color(0xFF0A0D0C);
  @override
  Color get containerLow => const Color(0xFF141815);
  @override
  Color get container => const Color(0xFF181D1A);
  @override
  Color get containerHigh => const Color(0xFF1F2521);
  @override
  Color get containerHighest => const Color(0xFF272E29);
  @override
  Color get dim => const Color(0xFF0A0D0C);
  @override
  Color get bright => const Color(0xFF333B35);
  @override
  Color get outline => const Color(0xFF4B5550);
  @override
  Color get outlineVariant => const Color(0xFF2A312C);
  @override
  Color get cardColor => const Color(0xFF161B18);
  @override
  Color get hairline => const Color(0xFF272E29);
}

/// Token accessors on [BuildContext] so widgets read tokens, not literals.
extension AppTokens on BuildContext {
  AppSpacing get space => Theme.of(this).extension<AppSpacing>()!;
  AppRadii get radii => Theme.of(this).extension<AppRadii>()!;
  AppMotion get motion => Theme.of(this).extension<AppMotion>()!;
  SemanticColors get semantic => Theme.of(this).extension<SemanticColors>()!;
  AppElevation get elevation => Theme.of(this).extension<AppElevation>()!;
  AppGradients get gradients => Theme.of(this).extension<AppGradients>()!;
  CategoryColors get categoryColors =>
      Theme.of(this).extension<CategoryColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}
