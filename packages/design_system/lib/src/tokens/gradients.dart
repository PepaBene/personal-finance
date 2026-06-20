import 'package:flutter/material.dart';

/// Brand gradient tokens (docs/12 §5). Used sparingly — chiefly the dashboard
/// balance hero — to give primary surfaces atmosphere without the flat,
/// generic look. Held as a [ThemeExtension] so the hero reads
/// `context.gradients.hero` and light/dark stay in sync.
@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  const AppGradients({required this.hero, required this.heroOn});

  /// Diagonal brand gradient for the primary spotlight surface.
  final LinearGradient hero;

  /// The foreground colour that meets AA on top of [hero].
  final Color heroOn;

  static const AppGradients light = AppGradients(
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2E7D6B), Color(0xFF1F5E54), Color(0xFF16433D)],
      stops: [0, 0.55, 1],
    ),
    heroOn: Color(0xFFF3FBF8),
  );

  static const AppGradients dark = AppGradients(
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E5048), Color(0xFF143A35), Color(0xFF0E2A27)],
      stops: [0, 0.55, 1],
    ),
    heroOn: Color(0xFFEAF5F1),
  );

  @override
  AppGradients copyWith({LinearGradient? hero, Color? heroOn}) {
    return AppGradients(hero: hero ?? this.hero, heroOn: heroOn ?? this.heroOn);
  }

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return AppGradients(
      hero: LinearGradient.lerp(hero, other.hero, t) ?? hero,
      heroOn: Color.lerp(heroOn, other.heroOn, t) ?? heroOn,
    );
  }
}
