import 'package:flutter/material.dart';

/// Motion tokens (docs/12 §3.5): durations 100/180/250ms + M3 easing.
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    this.fast = const Duration(milliseconds: 100),
    this.base = const Duration(milliseconds: 180),
    this.slow = const Duration(milliseconds: 250),
    this.standard = Curves.easeInOutCubicEmphasized,
    this.emphasized = Curves.easeOutCubic,
  });

  final Duration fast;
  final Duration base;
  final Duration slow;
  final Curve standard;
  final Curve emphasized;

  @override
  AppMotion copyWith({
    Duration? fast,
    Duration? base,
    Duration? slow,
    Curve? standard,
    Curve? emphasized,
  }) {
    return AppMotion(
      fast: fast ?? this.fast,
      base: base ?? this.base,
      slow: slow ?? this.slow,
      standard: standard ?? this.standard,
      emphasized: emphasized ?? this.emphasized,
    );
  }

  // Durations/curves are discrete; no meaningful interpolation between themes.
  @override
  AppMotion lerp(ThemeExtension<AppMotion>? other, double t) => this;
}
