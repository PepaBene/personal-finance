import 'package:design_system/design_system.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/analytics_service.dart';
import '../../core/di/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/category.dart';
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = MoneyFormatter(locale);
    final categories =
        ref.watch(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];

    return ListView(
      padding: EdgeInsets.all(context.space.md),
      children: [
        _presetBar(context, ref),
        SizedBox(height: context.space.md),
        _kpis(context, ref, fmt),
        SizedBox(height: context.space.lg),
        _Section(
          title: 'Spending by category',
          child: _categorySection(context, ref, fmt, categories),
        ),
        SizedBox(height: context.space.lg),
        _Section(
          title: 'Spending over time',
          child: _overTimeChart(context, ref),
        ),
        SizedBox(height: context.space.lg),
        _Section(
          title: 'Income vs expense',
          child: _incomeExpenseChart(context, ref),
        ),
        SizedBox(height: context.space.xl),
      ],
    );
  }

  Widget _presetBar(BuildContext context, WidgetRef ref) {
    final current = ref.watch(rangePresetProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in RangePreset.values)
            Padding(
              padding: EdgeInsets.only(right: context.space.xs),
              child: ChoiceChip(
                label: Text(p.label),
                selected: p == current,
                onSelected: (_) =>
                    ref.read(rangePresetProvider.notifier).state = p,
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpis(BuildContext context, WidgetRef ref, MoneyFormatter fmt) {
    final async = ref.watch(summaryProvider);
    final summary = async.valueOrNull;
    final income = summary?.income;
    final expense = summary?.expense;
    final net = summary?.net;
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'Income',
            value: income == null ? '—' : fmt.format(income),
            sign: MoneySign.positive,
            icon: Icons.south_west,
          ),
        ),
        SizedBox(width: context.space.sm),
        Expanded(
          child: KpiCard(
            label: 'Expense',
            value: expense == null ? '—' : fmt.format(expense),
            sign: MoneySign.negative,
            icon: Icons.north_east,
          ),
        ),
        SizedBox(width: context.space.sm),
        Expanded(
          child: KpiCard(
            label: 'Net',
            value: net == null ? '—' : fmt.format(net),
            sign: net == null
                ? MoneySign.neutral
                : (net.isNegative ? MoneySign.negative : MoneySign.positive),
            icon: Icons.account_balance_outlined,
          ),
        ),
      ],
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
      error: (e, _) => Text('$e'),
      data: (totals) {
        if (totals.isEmpty) {
          return const _EmptyChart('No spending in this period');
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
              radius: 56,
              showTitle: false,
            ),
          );
        }
        final top = totals.take(6).toList();
        return Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                ),
              ),
            ),
            SizedBox(height: context.space.sm),
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
    final name = cat?.name ?? 'Uncategorized';
    final color = cat == null
        ? context.colors.outline
        : categoryColor(cat.colorHex);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 8, backgroundColor: color),
      title: Text(name),
      trailing: MoneyText(formattedAmount: fmt.format(t.total)),
      onTap: () => _drillDown(context, ref, t.categoryId, name),
    );
  }

  Widget _overTimeChart(BuildContext context, WidgetRef ref) {
    final async = ref.watch(byPeriodProvider);
    return async.when(
      loading: () => const _ChartPlaceholder(),
      error: (e, _) => Text('$e'),
      data: (points) {
        if (points.isEmpty) return const _EmptyChart('No data in this period');
        final spots = <FlSpot>[
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].outflow.amount.toDouble()),
        ];
        return SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              minY: 0,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: context.semantic.expense,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: context.semantic.expense.withValues(alpha: 0.12),
                  ),
                ),
              ],
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
      error: (e, _) => Text('$e'),
      data: (points) {
        if (points.isEmpty) return const _EmptyChart('No data in this period');
        final groups = <BarChartGroupData>[
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].inflow.amount.toDouble(),
                  color: context.semantic.income,
                  width: 6,
                ),
                BarChartRodData(
                  toY: points[i].outflow.amount.toDouble(),
                  color: context.semantic.expense,
                  width: 6,
                ),
              ],
            ),
        ];
        return SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: groups,
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
                  ? const Center(child: Text('No transactions'))
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.texts.titleMedium),
            SizedBox(height: context.space.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 180,
    child: Center(child: CircularProgressIndicator()),
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
        style: TextStyle(color: context.colors.onSurfaceVariant),
      ),
    ),
  );
}
