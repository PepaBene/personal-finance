import 'package:design_system/design_system.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/analytics_service.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/category.dart';
import '../budgets/budget_providers.dart';
import '../categories/category_visuals.dart';
import '../transactions/capture_providers.dart';
import 'dashboard_providers.dart';

/// Dashboard / analytics (FR-ANL-01..05, 10): KPIs, spend-by-category donut,
/// over-time line, income-vs-expense bars, all in base currency, filtered by a
/// date-range preset, with drill-down into a category's transactions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = MoneyFormatter(locale);
    final categories = ref.watch(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];

    return ListView(
      padding: EdgeInsets.all(context.space.md),
      children: [
        _presetBar(context, ref),
        SizedBox(height: context.space.md),
        _hero(context, ref, fmt),
        _budgetAlerts(context, ref, fmt, categories),
        SizedBox(height: context.space.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: l10n.dashboardSpendingByCategory),
              SizedBox(height: context.space.md),
              _categorySection(context, ref, fmt, categories),
            ],
          ),
        ),
        SizedBox(height: context.space.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: l10n.dashboardSpendingOverTime),
              SizedBox(height: context.space.md),
              _overTimeChart(context, ref),
            ],
          ),
        ),
        SizedBox(height: context.space.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: l10n.dashboardIncomeVsExpense),
              SizedBox(height: context.space.md),
              _incomeExpenseChart(context, ref),
            ],
          ),
        ),
        SizedBox(height: context.space.xl),
      ],
    );
  }

  Widget _presetBar(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(rangePresetProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in RangePreset.values)
            Padding(
              padding: EdgeInsets.only(right: context.space.xs),
              child: ChoiceChip(
                label: Text(_presetLabel(l10n, p)),
                selected: p == current,
                onSelected: (_) =>
                    ref.read(rangePresetProvider.notifier).state = p,
              ),
            ),
        ],
      ),
    );
  }

  String _presetLabel(AppLocalizations l10n, RangePreset p) => switch (p) {
        RangePreset.thisMonth => l10n.rangePresetThisMonth,
        RangePreset.last30Days => l10n.rangePresetLast30Days,
        RangePreset.thisYear => l10n.rangePresetThisYear,
        RangePreset.last12Months => l10n.rangePresetLast12Months,
      };

  /// The hero "spotlight" surface: the period Net as the big serif figure, with
  /// Income and Expense folded into the footer stats (replaces the old KPI row).
  Widget _hero(BuildContext context, WidgetRef ref, MoneyFormatter fmt) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(summaryProvider);
    final summary = async.valueOrNull;
    final income = summary?.income;
    final expense = summary?.expense;
    final net = summary?.net;
    return SummaryHeroCard(
      label: l10n.dashboardNet,
      amount: net == null ? '—' : fmt.format(net),
      icon: Icons.account_balance_outlined,
      stats: [
        HeroStat(
          label: l10n.dashboardIncome,
          value: income == null ? '—' : fmt.format(income),
          icon: Icons.south_west,
        ),
        HeroStat(
          label: l10n.dashboardExpense,
          value: expense == null ? '—' : fmt.format(expense),
          icon: Icons.north_east,
        ),
      ],
    );
  }

  /// Surfaces budgets that are nearing or over their limit for the current
  /// month (FR-BUD-02, docs/11 §5.5). Hidden entirely when nothing needs
  /// attention. Tapping opens the Budgets screen.
  Widget _budgetAlerts(
    BuildContext context,
    WidgetRef ref,
    MoneyFormatter fmt,
    List<CategoryEntity> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final statuses = ref.watch(budgetStatusProvider).valueOrNull ?? const [];
    final alerts = statuses
        .where((s) => s.level != BudgetAlertLevel.ok)
        .toList(growable: false);
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.space.md),
      child: AppCard(
        onTap: () => context.push(Routes.budgets),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: context.semantic.warning,
                ),
                SizedBox(width: context.space.xs),
                Text(
                  l10n.dashboardBudgetAlertsTitle,
                  style: context.texts.titleSmall,
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
            SizedBox(height: context.space.xs),
            for (final s in alerts.take(3))
              Padding(
                padding: EdgeInsets.only(top: context.space.sm),
                child: Row(
                  children: [
                    Icon(
                      s.level == BudgetAlertLevel.over
                          ? Icons.error_outline
                          : Icons.warning_amber_outlined,
                      size: 16,
                      color: s.level == BudgetAlertLevel.over
                          ? context.semantic.danger
                          : context.semantic.warning,
                    ),
                    SizedBox(width: context.space.xs),
                    Expanded(
                      child: Text(
                        categoryById(categories, s.budget.categoryId)?.name ??
                            l10n.dashboardUncategorized,
                      ),
                    ),
                    Text(
                      l10n.budgetSpentOfLimit(
                        fmt.format(s.actual),
                        fmt.format(s.limit),
                      ),
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categorySection(
    BuildContext context,
    WidgetRef ref,
    MoneyFormatter fmt,
    List<CategoryEntity> categories,
  ) {
    final async = ref.watch(spendByCategoryProvider);
    return async.when(
      loading: () => const _ChartPlaceholder(),
      error: (e, _) => _ChartError(message: friendlyError(e)),
      data: (totals) {
        if (totals.isEmpty) {
          return _EmptyChart(AppLocalizations.of(context).dashboardNoSpending);
        }
        final sections = <PieChartSectionData>[];
        for (var i = 0; i < totals.length; i++) {
          final t = totals[i];
          final cat = categoryById(categories, t.categoryId);
          sections.add(
            PieChartSectionData(
              value: t.total.amount.toDouble(),
              color: cat == null
                  ? context.categoryColors.forIndex(i)
                  : categoryColor(cat.colorHex),
              radius: 48,
              showTitle: false,
            ),
          );
        }
        final top = totals.take(6).toList();
        return Column(
          children: [
            // The donut is decorative for a screen reader; the legend rows
            // below carry the same data accessibly (NFR-07).
            ExcludeSemantics(
              child: SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 3,
                    centerSpaceRadius: 48,
                  ),
                ),
              ),
            ),
            SizedBox(height: context.space.md),
            for (final t in top) _legendRow(context, ref, fmt, categories, t),
          ],
        );
      },
    );
  }

  Widget _legendRow(
    BuildContext context,
    WidgetRef ref,
    MoneyFormatter fmt,
    List<CategoryEntity> categories,
    CategoryTotal t,
  ) {
    final cat = categoryById(categories, t.categoryId);
    final name =
        cat?.name ?? AppLocalizations.of(context).dashboardUncategorized;
    final color =
        cat == null ? context.colors.outline : categoryColor(cat.colorHex);
    return InkWell(
      onTap: () => _drillDown(context, ref, t.categoryId, name),
      borderRadius: context.radii.smRadius,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.xs),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: context.space.sm),
            Expanded(
              child: Text(name, style: context.texts.bodyMedium),
            ),
            MoneyText(formattedAmount: fmt.format(t.total)),
          ],
        ),
      ),
    );
  }

  Widget _overTimeChart(BuildContext context, WidgetRef ref) {
    final async = ref.watch(byPeriodProvider);
    return async.when(
      loading: () => const _ChartPlaceholder(),
      error: (e, _) => _ChartError(message: friendlyError(e)),
      data: (points) {
        if (points.isEmpty) {
          return _EmptyChart(AppLocalizations.of(context).dashboardNoData);
        }
        final spots = <FlSpot>[
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].outflow.amount.toDouble()),
        ];
        final line = context.semantic.expense;
        return ExcludeSemantics(
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    barWidth: 2.5,
                    color: line,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          line.withValues(alpha: 0.20),
                          line.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _incomeExpenseChart(BuildContext context, WidgetRef ref) {
    final async = ref.watch(byPeriodProvider);
    return async.when(
      loading: () => const _ChartPlaceholder(),
      error: (e, _) => _ChartError(message: friendlyError(e)),
      data: (points) {
        if (points.isEmpty) {
          return _EmptyChart(AppLocalizations.of(context).dashboardNoData);
        }
        final radius = BorderRadius.vertical(
          top: Radius.circular(context.radii.sm),
        );
        final groups = <BarChartGroupData>[
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].inflow.amount.toDouble(),
                  color: context.semantic.income,
                  width: 6,
                  borderRadius: radius,
                ),
                BarChartRodData(
                  toY: points[i].outflow.amount.toDouble(),
                  color: context.semantic.expense,
                  width: 6,
                  borderRadius: radius,
                ),
              ],
            ),
        ];
        return ExcludeSemantics(
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                barGroups: groups,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _drillDown(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
    String name,
  ) async {
    final filter = ref.read(analyticsFilterProvider);
    final service = await ref.read(analyticsServiceProvider.future);
    final txs = await service.transactionsInCategory(categoryId, filter.range);
    if (!context.mounted) return;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = MoneyFormatter(locale);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(context.space.md),
              child: Text(name, style: context.texts.titleLarge),
            ),
            Expanded(
              child: txs.isEmpty
                  ? EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title:
                          AppLocalizations.of(context).dashboardDrillEmptyTitle,
                      message:
                          AppLocalizations.of(context).dashboardDrillEmptyBody,
                    )
                  : ListView.builder(
                      itemCount: txs.length,
                      itemBuilder: (_, i) {
                        final tx = txs[i];
                        return ListTile(
                          title: Text(
                            tx.note?.isNotEmpty == true
                                ? tx.note!
                                : tx.date.toLocal().toString().split(' ').first,
                          ),
                          trailing: MoneyText(
                            formattedAmount: fmt.format(tx.total),
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            context.push(Routes.transactionEdit(tx.id));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 180,
        child: Center(
          child: Skeleton(
            width: 140,
            height: 140,
            borderRadius: context.radii.mdRadius,
          ),
        ),
      );
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 120, child: ErrorView(message: message, compact: true));
}
