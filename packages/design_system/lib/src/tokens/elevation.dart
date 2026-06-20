import 'package:flutter/material.dart';

/// Soft, layered shadow tokens (docs/12 §5). The "refined & calm" look replaces
/// Material's tonal elevation overlays with gentle, two-stop shadows on light
/// surfaces and very restrained shadows on dark (where depth comes mostly from
/// layered surface tints). Held as a [ThemeExtension] so widgets read
/// `context.elevation.card` instead of hard-coding `BoxShadow`s.
@immutable
class AppElevation extends ThemeExtension<AppElevation> {
  const AppElevation({
    required this.card,
    required this.raised,
    required this.hero,
  });

  /// Resting cards, list tiles, chips.
  final List<BoxShadow> card;

  /// Menus, dialogs, FABs, anything that floats above content.
  final List<BoxShadow> raised;

  /// The dashboard balance hero and other primary spotlight surfaces.
  final List<BoxShadow> hero;

  static const AppElevation light = AppElevation(
    card: [
      BoxShadow(
        color: Color(0x0D101828), // ~5% slate
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color(0x14101828), // ~8% slate
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
    raised: [
      BoxShadow(
        color: Color(0x1A101828),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
      BoxShadow(
        color: Color(0x24101828),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
    hero: [
      BoxShadow(
        color: Color(0x2E1B5A4E), // brand-tinted, soft
        blurRadius: 36,
        offset: Offset(0, 18),
      ),
    ],
  );

  static const AppElevation dark = AppElevation(
    card: [
      BoxShadow(
        color: Color(0x59000000), // 35% black, tight
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 14,
        offset: Offset(0, 6),
      ),
    ],
    raised: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
    ],
    hero: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 40,
        offset: Offset(0, 20),
      ),
    ],
  );

  @override
  AppElevation copyWith({
    List<BoxShadow>? card,
    List<BoxShadow>? raised,
    List<BoxShadow>? hero,
  }) {
    return AppElevation(
      card: card ?? this.card,
      raised: raised ?? this.raised,
      hero: hero ?? this.hero,
    );
  }

  @override
  AppElevation lerp(ThemeExtension<AppElevation>? other, double t) {
    if (other is! AppElevation) return this;
    return AppElevation(
      card: BoxShadow.lerpList(card, other.card, t) ?? card,
      raised: BoxShadow.lerpList(raised, other.raised, t) ?? raised,
      hero: BoxShadow.lerpList(hero, other.hero, t) ?? hero,
    );
  }
}
