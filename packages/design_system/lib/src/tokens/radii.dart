import 'package:flutter/material.dart';

/// Corner-radius tokens (docs/12 §5: radius.{sm,md,lg,pill}).
@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({this.sm = 8, this.md = 12, this.lg = 20, this.pill = 999});

  final double sm;
  final double md;
  final double lg;
  final double pill;

  BorderRadius get smRadius => BorderRadius.circular(sm);
  BorderRadius get mdRadius => BorderRadius.circular(md);
  BorderRadius get lgRadius => BorderRadius.circular(lg);
  BorderRadius get pillRadius => BorderRadius.circular(pill);

  @override
  AppRadii copyWith({double? sm, double? md, double? lg, double? pill}) {
    return AppRadii(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      pill: pill ?? this.pill,
    );
  }

  @override
  AppRadii lerp(ThemeExtension<AppRadii>? other, double t) {
    if (other is! AppRadii) return this;
    return AppRadii(
      sm: _l(sm, other.sm, t),
      md: _l(md, other.md, t),
      lg: _l(lg, other.lg, t),
      pill: _l(pill, other.pill, t),
    );
  }

  static double _l(double a, double b, double t) => a + (b - a) * t;
}
