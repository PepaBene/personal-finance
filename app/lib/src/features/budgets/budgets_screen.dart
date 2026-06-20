import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/analytics_service.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../categories/category_visuals.dart';
import '../transactions/capture_providers.dart';
import 'budget_providers.dart';

/// Budgets (FR-BUD-01/02, FR-ANL-06): set a monthly limit per category and track
/// actual-vs-budget for the current month with over/near alerts.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = MoneyFormatter(locale);
    final categories = ref.watch(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];
    final statusAsync = ref.watch(budgetStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _BudgetSheet.show(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.budgetsAddAction),
      ),
      body: statusAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(budgetStatusProvider),
        ),
        data: (statuses) {
          if (statuses.isEmpty) {
            return EmptyView(
              icon: Icons.savings_outlined,
              title: l10n.budgetsEmptyTitle,
              message: l10n.budgetsEmptyBody,
              action: FilledButton.icon(
                onPressed: () => _BudgetSheet.show(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.budgetsAddAction),
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(context.space.md),
            itemCount: statuses.length,
            itemBuilder: (_, i) => _BudgetTile(
              status: statuses[i],
              category: categoryById(categories, statuses[i].budget.categoryId),
              fmt: fmt,
            ),
            separatorBuilder: (_, __) => SizedBox(height: context.space.sm),
          );
        },
      ),
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile({
    required this.status,
    required this.category,
    required this.fmt,
  });

  final BudgetStatus status;
  final CategoryEntity? category;
  final MoneyFormatter fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (barColor, label, icon) = switch (status.level) {
      BudgetAlertLevel.over => (
          context.semantic.danger,
          l10n.budgetOver,
          Icons.error_outline,
        ),
      BudgetAlertLevel.nearing => (
          context.semantic.warning,
          l10n.budgetNearing,
          Icons.warning_amber_outlined,
        ),
      BudgetAlertLevel.ok => (
          context.semantic.success,
          l10n.budgetOnTrack,
          Icons.check_circle_outline,
        ),
    };
    final name = category?.name ?? l10n.dashboardUncategorized;
    final fraction = status.utilization.clamp(0.0, 1.0).toDouble();
    final avatarColor = category == null
        ? context.colors.outline
        : categoryColor(category!.colorHex);
    return AppCard(
      onTap: () => _BudgetSheet.show(context, ref, budget: status.budget),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CategoryAvatar(
                icon: category == null
                    ? Icons.category_outlined
                    : categoryIcon(category!.icon),
                color: avatarColor,
                size: 40,
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                child: Text(name, style: context.texts.titleMedium),
              ),
              Icon(icon, size: 18, color: barColor),
              SizedBox(width: context.space.xs),
              Text(
                label,
                style: context.texts.labelMedium?.copyWith(color: barColor),
              ),
            ],
          ),
          SizedBox(height: context.space.md),
          ClipRRect(
            borderRadius: context.radii.pillRadius,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: context.colors.surfaceContainerHigh,
              color: barColor,
            ),
          ),
          SizedBox(height: context.space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.budgetSpentOfLimit(
                  fmt.format(status.actual),
                  fmt.format(status.limit),
                ),
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              Text(
                '${(status.utilization * 100).round()}%',
                style: context.texts.labelMedium?.copyWith(color: barColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.budget});
  final BudgetEntity? budget;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    BudgetEntity? budget,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BudgetSheet(budget: budget),
    );
  }

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _amountCtrl = TextEditingController();
  String? _categoryId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    if (b != null) {
      _categoryId = b.categoryId;
      _amountCtrl.text = b.amount.amount.toString();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final categoryId = _categoryId;
      if (categoryId == null) throw Exception(l10n.budgetValidationCategory);
      final amount = Decimal.tryParse(_amountCtrl.text.trim());
      if (amount == null || amount <= Decimal.zero) {
        throw Exception(l10n.budgetValidationAmount);
      }
      final session = ref.read(authServiceProvider).current.session!;
      final base = await ref.read(baseCurrencyProvider.future);
      final service = await ref.read(budgetServiceProvider.future);
      final existing = widget.budget;
      final now = DateTime.now().toUtc();
      await service.upsert(
        BudgetEntity(
          id: existing?.id ?? const Uuid().v4(),
          userId: session.userId,
          categoryId: categoryId,
          amount: Money(amount, base),
          startMonth: existing?.startMonth ?? DateTime.utc(now.year, now.month),
          isActive: true,
          updatedAt: now,
          version: existing?.version ?? 0,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.budget;
    if (existing == null) return;
    setState(() => _busy = true);
    final service = await ref.read(budgetServiceProvider.future);
    await service.delete(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(categoriesFlatProvider).valueOrNull ?? const [];
    // Budgets are expense limits; offer non-archived expense categories.
    final options =
        all.where((c) => c.kind == CategoryKind.expense && !c.isArchived);
    final selectable =
        options.any((c) => c.id == _categoryId) ? _categoryId : null;
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(
        left: context.space.lg,
        right: context.space.lg,
        top: context.space.sm,
        bottom: context.space.lg + insets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.budget == null
                ? l10n.budgetNewTitle
                : l10n.budgetEditTitle,
            style: context.texts.titleLarge,
          ),
          SizedBox(height: context.space.md),
          DropdownButtonFormField<String>(
            value: selectable,
            decoration: InputDecoration(labelText: l10n.budgetCategory),
            items: [
              for (final c in options)
                DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          SizedBox(height: context.space.sm),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.budgetMonthlyLimit),
          ),
          if (_error != null) ...[
            SizedBox(height: context.space.sm),
            Text(
              _error!,
              style: context.texts.bodySmall?.copyWith(
                color: context.semantic.danger,
              ),
            ),
          ],
          SizedBox(height: context.space.lg),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const ButtonSpinner() : Text(l10n.budgetSave),
          ),
          if (widget.budget != null) ...[
            SizedBox(height: context.space.xs),
            TextButton.icon(
              onPressed: _busy ? null : _delete,
              icon: Icon(Icons.delete_outline, color: context.semantic.danger),
              label: Text(
                l10n.budgetDelete,
                style: TextStyle(color: context.semantic.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
