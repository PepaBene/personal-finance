import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// A secondary statistic shown in the [SummaryHeroCard] footer (e.g. Income /
/// Expense beneath a Net hero figure). Pre-format [value] for the locale.
class HeroStat {
  const HeroStat({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;
}

/// The "spotlight" surface (docs/12 §4): a brand-gradient card with a big serif
/// money figure, an optional delta pill, and an optional row of secondary
/// stats. Anchors the dashboard and account overview. Foreground colours come
/// from `context.gradients.heroOn` so text stays AA on the gradient.
class SummaryHeroCard extends StatelessWidget {
  const SummaryHeroCard({
    required this.label,
    required this.amount,
    this.deltaLabel,
    this.deltaPositive,
    this.stats = const [],
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;

  /// Pre-formatted primary amount string (locale-aware via `intl`).
  final String amount;

  /// Optional change descriptor, e.g. "↑ 12% vs last month".
  final String? deltaLabel;

  /// Tints the delta pill; null = neutral.
  final bool? deltaPositive;

  final List<HeroStat> stats;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gradients;
    final on = g.heroOn;

    final card = Container(
      decoration: BoxDecoration(
        gradient: g.hero,
        borderRadius: context.radii.lgRadius,
        boxShadow: context.elevation.hero,
      ),
      padding: EdgeInsets.all(context.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.texts.labelLarge?.copyWith(
                    color: on.withValues(alpha: 0.82),
                  ),
                ),
              ),
              if (icon != null)
                Icon(icon, size: 20, color: on.withValues(alpha: 0.7)),
            ],
          ),
          SizedBox(height: context.space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.moneyStyle(40, wght: 600, useDisplay: true)
                      .copyWith(color: on, height: 1.0),
                ),
              ),
              if (deltaLabel != null) ...[
                SizedBox(width: context.space.sm),
                Padding(
                  padding: EdgeInsets.only(bottom: context.space.xxs),
                  child: _DeltaPill(
                    label: deltaLabel!,
                    positive: deltaPositive,
                    on: on,
                  ),
                ),
              ],
            ],
          ),
          if (stats.isNotEmpty) ...[
            SizedBox(height: context.space.md),
            Divider(color: on.withValues(alpha: 0.18), height: 1),
            SizedBox(height: context.space.md),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 28,
                      color: on.withValues(alpha: 0.18),
                    ),
                  Expanded(child: _StatCell(stat: stats[i], on: on)),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: context.radii.lgRadius,
      child: card,
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.label, required this.positive, required this.on});
  final String label;
  final bool? positive;
  final Color on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.xs,
        vertical: context.space.xxs,
      ),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.16),
        borderRadius: context.radii.pillRadius,
      ),
      child: Text(
        label,
        style: context.texts.labelMedium?.copyWith(color: on),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat, required this.on});
  final HeroStat stat;
  final Color on;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (stat.icon != null) ...[
                Icon(stat.icon, size: 13, color: on.withValues(alpha: 0.7)),
                SizedBox(width: context.space.xxs),
              ],
              Flexible(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    color: on.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.xxs),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.moneyStyle(16, wght: 600).copyWith(color: on),
          ),
        ],
      ),
    );
  }
}
