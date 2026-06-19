import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/analytics_service.dart';
import '../../application/report_service.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/money.dart';
import '../budgets/budget_providers.dart';
import '../categories/category_visuals.dart';
import '../dashboard/dashboard_providers.dart';
import '../transactions/capture_providers.dart';
import 'analytics_providers.dart';

/// Advanced analysis (FR-ANL-07/08/09): top merchants, daily-spend heatmap,
/// month/year category comparison, category treemap and a cash-flow waterfall —
/// all in base currency, sharing the dashboard's date-range filter.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = MoneyFormatter(locale);
    final categories = ref.watch(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analyticsTitle),
        actions: [
          IconButton(
            tooltip: l10n.analyticsExportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _exportPdf(context, ref, fmt, categories),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(context.space.md),
        children: [
          _presetBar(context, ref),
          SizedBox(height: context.space.md),
          _Section(
            title: l10n.analyticsTopMerchants,
            child: _topMerchants(context, ref, fmt),
          ),
          SizedBox(height: context.space.lg),
          _Section(
            title: l10n.analyticsHeatmap,
            child: _heatmap(context, ref, fmt),
          ),
          SizedBox(height: context.space.lg),
          _Section(
            title: l10n.analyticsComparison,
            child: _comparison(context, ref, categories),
          ),
          SizedBox(height: context.space.lg),
          _Section(
            title: l10n.analyticsTreemap,
            child: _treemap(context, ref, fmt, categories),
          ),
          SizedBox(height: context.space.lg),
          _Section(
            title: l10n.analyticsWaterfall,
            child: _waterfall(context, ref, fmt, categories),
          ),
          SizedBox(height: context.space.xl),
        ],
      ),
    );
  }

  Widget _presetBar(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(rangePresetProvider);
    String label(RangePreset p) => switch (p) {
          RangePreset.thisMonth => l10n.rangePresetThisMonth,
          RangePreset.last30Days => l10n.rangePresetLast30Days,
          RangePreset.thisYear => l10n.rangePresetThisYear,
          RangePreset.last12Months => l10n.rangePresetLast12Months,
        };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in RangePreset.values)
            Padding(
              padding: EdgeInsets.only(right: context.space.xs),
              child: ChoiceChip(
                label: Text(label(p)),
                selected: p == current,
                onSelected: (_) =>
                    ref.read(rangePresetProvider.notifier).state = p,
              ),
            ),
        ],
      ),
    );
  }

  // --- Top merchants (ranked bars) --------------------------------------

  Widget _topMerchants(BuildContext context, WidgetRef ref, MoneyFormatter f) {
    final async = ref.watch(topMerchantsProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => _Error(message: friendlyError(e)),
      data: (merchants) {
        if (merchants.isEmpty) return _empty(context);
        final max = merchants.first.total.amount.toDouble();
        return Column(
          children: [
            for (var i = 0; i < merchants.length; i++)
              _RankedBar(
                label: merchants[i].name,
                value: f.format(merchants[i].total),
                fraction: max <= 0
                    ? 0
                    : merchants[i].total.amount.toDouble() / max,
                color: context.categoryColors.forIndex(i),
                onTap: () => _drillMerchant(
                  context,
                  ref,
                  merchants[i].merchantId,
                  merchants[i].name,
                ),
              ),
          ],
        );
      },
    );
  }

  // --- Calendar heatmap --------------------------------------------------

  Widget _heatmap(BuildContext context, WidgetRef ref, MoneyFormatter f) {
    final async = ref.watch(dailySpendProvider);
    final filter = ref.watch(analyticsFilterProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => _Error(message: friendlyError(e)),
      data: (days) {
        if (days.isEmpty) return _empty(context);
        return _CalendarHeatmap(days: days, range: filter.range, fmt: f);
      },
    );
  }

  // --- MoM / YoY comparison (clustered bars) ----------------------------

  Widget _comparison(
    BuildContext context,
    WidgetRef ref,
    List<CategoryEntity> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(categoryComparisonProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => _Error(message: friendlyError(e)),
      data: (rows) {
        final movers = rows.take(6).toList();
        if (movers.isEmpty) return _empty(context);
        final maxY = movers
            .map((c) => math.max(
                  c.current.amount.toDouble(),
                  c.previous.amount.toDouble(),
                ))
            .fold<double>(0, (a, b) => math.max(a, b));
        final groups = <BarChartGroupData>[
          for (var i = 0; i < movers.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: movers[i].previous.amount.toDouble(),
                  color: context.colors.outline,
                  width: 7,
                ),
                BarChartRodData(
                  toY: movers[i].current.amount.toDouble(),
                  color: context.semantic.expense,
                  width: 7,
                ),
              ],
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _legend(context, [
              (context.colors.outline, l10n.analyticsPrevious),
              (context.semantic.expense, l10n.analyticsCurrent),
            ]),
            SizedBox(height: context.space.sm),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY == 0 ? 1 : maxY * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= movers.length) {
                            return const SizedBox.shrink();
                          }
                          final cat =
                              categoryById(categories, movers[i].categoryId);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              cat?.name ?? '—',
                              style: context.texts.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: groups,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Treemap (binary slice-and-dice) ----------------------------------

  Widget _treemap(
    BuildContext context,
    WidgetRef ref,
    MoneyFormatter f,
    List<CategoryEntity> categories,
  ) {
    final async = ref.watch(spendByCategoryProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => _Error(message: friendlyError(e)),
      data: (totals) {
        if (totals.isEmpty) return _empty(context);
        final tiles = <_TreemapTile>[
          for (var i = 0; i < totals.length; i++)
            () {
              final cat = categoryById(categories, totals[i].categoryId);
              return _TreemapTile(
                weight: totals[i].total.amount.toDouble(),
                label: cat?.name ??
                    AppLocalizations.of(context).dashboardUncategorized,
                value: f.format(totals[i].total),
                color: cat == null
                    ? context.categoryColors.forIndex(i)
                    : categoryColor(cat.colorHex),
                onTap: () => _drillCategory(
                  context,
                  ref,
                  totals[i].categoryId,
                  cat?.name ??
                      AppLocalizations.of(context).dashboardUncategorized,
                ),
              );
            }(),
        ];
        return SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: _Treemap(tiles: tiles),
          ),
        );
      },
    );
  }

  // --- Cash-flow waterfall ----------------------------------------------

  Widget _waterfall(
    BuildContext context,
    WidgetRef ref,
    MoneyFormatter f,
    List<CategoryEntity> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(waterfallProvider);
    return async.when(
      loading: () => const _Loading(),
      error: (e, _) => _Error(message: friendlyError(e)),
      data: (steps) {
        if (steps.isEmpty) return _empty(context);
        String label(WaterfallStep s) => switch (s.key) {
              'income' => l10n.waterfallIncome,
              'other' => l10n.analyticsOther,
              'net' => l10n.waterfallNet,
              _ => categoryById(categories, s.key)?.name ??
                  l10n.dashboardUncategorized,
            };
        return _Waterfall(
          steps: steps,
          labelOf: label,
          fmt: f,
        );
      },
    );
  }

  // --- shared ------------------------------------------------------------

  Widget _legend(BuildContext context, List<(Color, String)> items) {
    return Wrap(
      spacing: context.space.md,
      children: [
        for (final (color, text) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: context.space.xs),
              Text(text, style: context.texts.labelSmall),
            ],
          ),
      ],
    );
  }

  Widget _empty(BuildContext context) => SizedBox(
        height: 100,
        child: Center(
          child: Text(
            AppLocalizations.of(context).dashboardNoData,
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );

  /// Assembles the current period's figures and exports them as an on-device
  /// PDF (FR-DAT-06), saved to a user-chosen file. Works fully offline.
  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    MoneyFormatter fmt,
    List<CategoryEntity> categories,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final preset = ref.read(rangePresetProvider);
    final periodLabel = switch (preset) {
      RangePreset.thisMonth => l10n.rangePresetThisMonth,
      RangePreset.last30Days => l10n.rangePresetLast30Days,
      RangePreset.thisYear => l10n.rangePresetThisYear,
      RangePreset.last12Months => l10n.rangePresetLast12Months,
    };
    try {
      final filter = ref.read(analyticsFilterProvider);
      final analytics = await ref.read(analyticsServiceProvider.future);
      final summary = await analytics.watchSummary(filter.range).first;
      final cats = await analytics.watchSpendByCategory(filter.range).first;
      final merchants = await analytics.watchTopMerchants(filter.range).first;
      final budgets =
          await analytics.watchBudgetStatus(currentMonthRange()).first;

      String catName(String id) =>
          categoryById(categories, id)?.name ?? l10n.dashboardUncategorized;

      final data = ReportData(
        title: l10n.appTitle,
        periodLabel: periodLabel,
        generatedOn: DateTime.now().toLocal().toString().split('.').first,
        income: fmt.format(summary.income),
        expense: fmt.format(summary.expense),
        net: fmt.format(summary.net),
        topCategories: [
          for (final c in cats.take(10))
            ReportLine(label: catName(c.categoryId), value: fmt.format(c.total)),
        ],
        topMerchants: [
          for (final m in merchants.take(10))
            ReportLine(label: m.name, value: fmt.format(m.total)),
        ],
        budgets: [
          for (final b in budgets)
            ReportLine(
              label: catName(b.budget.categoryId),
              detail: ReportService.budgetMarker(b.level),
              value: '${fmt.format(b.actual)} / ${fmt.format(b.limit)}',
            ),
        ],
        labels: ReportLabels(
          summary: l10n.reportSummary,
          income: l10n.dashboardIncome,
          expense: l10n.dashboardExpense,
          net: l10n.dashboardNet,
          topCategories: l10n.analyticsTreemap,
          topMerchants: l10n.analyticsTopMerchants,
          budgets: l10n.budgetsTitle,
          generatedOn: l10n.reportGeneratedOn,
        ),
      );

      final bytes = await ref.read(reportServiceProvider).buildPdf(data);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.reportExportDialogTitle,
        fileName: l10n.reportFileName,
        bytes: bytes,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            path == null ? l10n.reportExportCancelled : l10n.reportExportedTo(path),
          ),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reportExportFailed(friendlyError(e)))),
      );
    }
  }

  Future<void> _drillCategory(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
    String name,
  ) async {
    final filter = ref.read(analyticsFilterProvider);
    final service = await ref.read(analyticsServiceProvider.future);
    final txs = await service.transactionsInCategory(categoryId, filter.range);
    if (!context.mounted) return;
    await _showTransactions(context, name, txs);
  }

  Future<void> _drillMerchant(
    BuildContext context,
    WidgetRef ref,
    String merchantId,
    String name,
  ) async {
    final filter = ref.read(analyticsFilterProvider);
    final service = await ref.read(analyticsServiceProvider.future);
    final txs = await service.transactionsForMerchant(merchantId, filter.range);
    if (!context.mounted) return;
    await _showTransactions(context, name, txs);
  }

  Future<void> _showTransactions(
    BuildContext context,
    String name,
    List<TransactionEntity> txs,
  ) async {
    final fmt = MoneyFormatter(Localizations.localeOf(context).toLanguageTag());
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
                          trailing:
                              MoneyText(formattedAmount: fmt.format(tx.total)),
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

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 120, child: ErrorView(message: message, compact: true));
}

/// A single labelled bar in a ranked list (top merchants); tappable to drill in.
class _RankedBar extends StatelessWidget {
  const _RankedBar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    this.onTap,
  });
  final String label;
  final String value;
  final double fraction;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
                Text(value, style: context.texts.labelMedium),
              ],
            ),
            SizedBox(height: context.space.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.sm),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: context.colors.surfaceContainerHighest,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GitHub-style calendar heatmap: week columns of day cells, shaded by spend
/// intensity (FR-ANL-07, docs/11 §7). Drawn from layout primitives only.
class _CalendarHeatmap extends StatelessWidget {
  const _CalendarHeatmap({
    required this.days,
    required this.range,
    required this.fmt,
  });
  final List<DailySpend> days;
  final DateRange range;
  final MoneyFormatter fmt;

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, Money>{for (final d in days) d.day: d.amount};
    final maxV = days
        .map((d) => d.amount.amount.toDouble())
        .fold<double>(0, (a, b) => math.max(a, b));
    final base = context.semantic.expense;

    // Align the grid to the Monday on/before the range start.
    final start = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final gridStart =
        start.subtract(Duration(days: (start.weekday - DateTime.monday) % 7));
    final end = range.endExclusive;

    final weeks = <Widget>[];
    var cursor = gridStart;
    var guard = 0;
    while (cursor.isBefore(end) && guard < 54) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        final day = cursor.add(Duration(days: i));
        final inRange = !day.isBefore(start) && day.isBefore(end);
        final spend = byDay[day];
        final intensity =
            (spend == null || maxV <= 0) ? 0.0 : spend.amount.toDouble() / maxV;
        final dayLabel = day.toIso8601String().split('T').first;
        cells.add(
          Tooltip(
            message:
                spend == null ? dayLabel : '$dayLabel: ${fmt.format(spend)}',
            child: Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: !inRange
                    ? Colors.transparent
                    : intensity == 0
                        ? context.colors.surfaceContainerHighest
                        : base.withValues(alpha: 0.2 + 0.8 * intensity),
              ),
            ),
          ),
        );
      }
      weeks.add(Column(mainAxisSize: MainAxisSize.min, children: cells));
      cursor = cursor.add(const Duration(days: 7));
      guard++;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: weeks),
    );
  }
}

/// Recursive binary slice-and-dice treemap: splits the tile list into two
/// weight-balanced halves, alternating the split axis at each level. Pure
/// layout (Expanded flex), so it works on every platform without a chart lib.
class _Treemap extends StatelessWidget {
  const _Treemap({required this.tiles});
  final List<_TreemapTile> tiles;

  @override
  Widget build(BuildContext context) => _build(tiles, horizontal: true);

  Widget _build(List<_TreemapTile> items, {required bool horizontal}) {
    if (items.length == 1) return items.first;
    // Partition into two halves with roughly equal total weight.
    final total = items.fold<double>(0, (s, t) => s + t.weight);
    var acc = 0.0;
    var split = 1;
    for (var i = 0; i < items.length - 1; i++) {
      acc += items[i].weight;
      split = i + 1;
      if (acc >= total / 2) break;
    }
    final left = items.sublist(0, split);
    final right = items.sublist(split);
    final leftWeight = left.fold<double>(0, (s, t) => s + t.weight);
    final rightWeight = right.fold<double>(0, (s, t) => s + t.weight);
    // Expanded (tight fit) so each partition fills its proportional slice;
    // Flexible (loose) would let leaf tiles shrink to their content.
    final children = [
      Expanded(
        flex: math.max(1, (leftWeight * 1000).round()),
        child: _build(left, horizontal: !horizontal),
      ),
      Expanded(
        flex: math.max(1, (rightWeight * 1000).round()),
        child: _build(right, horizontal: !horizontal),
      ),
    ];
    return horizontal
        ? Row(children: children)
        : Column(children: children);
  }
}

class _TreemapTile extends StatelessWidget {
  const _TreemapTile({
    required this.weight,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final double weight;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall?.copyWith(color: onColor),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    color: onColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating-bar cash-flow waterfall (docs/11 §4.2). Each step's bar starts at
/// the running total and moves up (income) or down (expense); total steps are
/// drawn from zero. Pure layout over a shared value→pixel scale.
class _Waterfall extends StatelessWidget {
  const _Waterfall({
    required this.steps,
    required this.labelOf,
    required this.fmt,
  });
  final List<WaterfallStep> steps;
  final String Function(WaterfallStep) labelOf;
  final MoneyFormatter fmt;

  @override
  Widget build(BuildContext context) {
    // Compute running totals and the value extent for scaling.
    var running = 0.0;
    final bottoms = <double>[];
    final tops = <double>[];
    var minV = 0.0;
    var maxV = 0.0;
    for (final s in steps) {
      final delta = s.delta.amount.toDouble();
      final double b;
      final double t;
      if (s.isTotal) {
        b = 0;
        t = delta;
      } else {
        b = running;
        t = running + delta;
        running = t;
      }
      bottoms.add(math.min(b, t));
      tops.add(math.max(b, t));
      minV = math.min(minV, math.min(b, t));
      maxV = math.max(maxV, math.max(b, t));
    }
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    const chartHeight = 160.0;
    double y(double v) => chartHeight * (1 - (v - minV) / span);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            // Stretch so each column's Stack gets a tight chartHeight to
            // position its bar against (a loose Stack would collapse to 0).
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: y(tops[i]),
                          height: math.max(2, y(bottoms[i]) - y(tops[i])),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _color(context, steps[i]),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: context.space.xs),
        Row(
          children: [
            for (final s in steps)
              Expanded(
                child: Text(
                  labelOf(s),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _color(BuildContext context, WaterfallStep s) {
    if (s.isTotal) return context.semantic.transfer;
    return s.delta.isNegative
        ? context.semantic.expense
        : context.semantic.income;
  }
}
