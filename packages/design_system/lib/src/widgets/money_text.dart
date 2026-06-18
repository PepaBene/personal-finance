import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sign of a money value, used to pick a semantic color without leaking the
/// `Money`/`Decimal` domain type into the design system.
enum MoneySign { positive, negative, neutral }

/// Specialized money display: right-aligned, tabular figures, currency-marked,
/// sign-aware semantic color (docs/12 §4 MoneyText, P3). Never truncates.
///
/// The caller pre-formats the numeric string (locale-aware, via `intl`) and the
/// currency marker so this widget stays pure-presentation and platform-neutral.
class MoneyText extends StatelessWidget {
  const MoneyText({
    required this.formattedAmount,
    this.sign = MoneySign.neutral,
    this.style,
    this.semanticsLabel,
    super.key,
  });

  final String formattedAmount;
  final MoneySign sign;
  final TextStyle? style;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final color = switch (sign) {
      MoneySign.positive => context.semantic.income,
      MoneySign.negative => context.semantic.expense,
      MoneySign.neutral => context.colors.onSurface,
    };

    final base = (style ?? context.texts.bodyMedium ?? const TextStyle())
        .copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Text(
      formattedAmount,
      textAlign: TextAlign.right,
      style: base,
      maxLines: 1,
      overflow: TextOverflow.visible,
      semanticsLabel: semanticsLabel,
    );
  }
}
