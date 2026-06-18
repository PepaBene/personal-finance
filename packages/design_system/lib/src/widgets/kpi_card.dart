import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'money_text.dart';

/// Dashboard KPI tile (docs/12 §4 KpiCard): label + big value, sign-aware color.
/// Pure presentation — the caller pre-formats the value string.
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
                  SizedBox(width: context.space.xxs),
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
            SizedBox(height: context.space.xs),
            MoneyText(
              formattedAmount: value,
              sign: sign,
              style: context.texts.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
