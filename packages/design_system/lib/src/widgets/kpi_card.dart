import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'app_card.dart';
import 'money_text.dart';

/// Dashboard KPI tile (docs/12 §4 KpiCard): a small label over a big,
/// sign-aware money figure on a soft [AppCard]. Pure presentation — the caller
/// pre-formats the value string.
class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    this.sign = MoneySign.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final MoneySign sign;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Read the label and value as a single node ("Income, €1,000") rather than
    // two fragments, and drop the duplicate inner text semantics (NFR-07).
    return Semantics(
      container: true,
      label: '$label, $value',
      child: ExcludeSemantics(child: _card(context)),
    );
  }

  Widget _card(BuildContext context) {
    final accent = switch (sign) {
      MoneySign.positive => context.semantic.income,
      MoneySign.negative => context.semantic.expense,
      MoneySign.neutral => context.colors.onSurfaceVariant,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: context.radii.smRadius,
                  ),
                  child: Icon(icon, size: 15, color: accent),
                ),
                SizedBox(width: context.space.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: context.texts.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.sm),
          MoneyText(
            formattedAmount: value,
            sign: sign,
            style: AppTypography.moneyStyle(22, wght: 600),
          ),
        ],
      ),
    );
  }
}
