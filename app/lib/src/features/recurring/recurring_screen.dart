import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../../domain/rules/recurring_detector.dart';
import '../transactions/capture_providers.dart';
import 'recurring_providers.dart';

/// Recurring transactions (FR-CAP-07) and subscription detection (FR-ANL-08):
/// manage templates that auto-generate entries, run generation on demand, and
/// turn detected recurring charges into templates.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = MoneyFormatter(locale);
    final templatesAsync = ref.watch(recurringTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recurringTitle),
        actions: [
          IconButton(
            tooltip: l10n.recurringGenerate,
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => _generate(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _TemplateSheet.show(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.recurringAddAction),
      ),
      body: templatesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(recurringTemplatesProvider),
        ),
        data: (templates) {
          return ListView(
            padding: EdgeInsets.all(context.space.md),
            children: [
              if (templates.isEmpty)
                _EmptyTemplates()
              else
                for (final t in templates)
                  _TemplateTile(template: t, fmt: fmt),
              SizedBox(height: context.space.lg),
              _DetectedSection(fmt: fmt),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = await ref.read(recurringServiceProvider.future);
    final count = await service.generateDue(DateTime.now().toUtc());
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.recurringGenerated(count))),
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.xl),
      child: EmptyView(
        icon: Icons.event_repeat_outlined,
        title: l10n.recurringEmptyTitle,
        message: l10n.recurringEmptyBody,
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template, required this.fmt});
  final RecurringTemplateEntity template;
  final MoneyFormatter fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final next = template.nextDate.toLocal().toString().split(' ').first;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.colors.secondaryContainer,
          child: const Icon(Icons.event_repeat_outlined, size: 20),
        ),
        title: Text(template.name),
        subtitle: Text(
          '${_frequencyLabel(l10n, template.frequency)} · '
          '${l10n.recurringNext(next)}',
        ),
        trailing: Text(
          fmt.format(template.amount),
          style: context.texts.titleMedium,
        ),
        onTap: () => _TemplateSheet.show(context, ref, template: template),
      ),
    );
  }
}

class _DetectedSection extends ConsumerWidget {
  const _DetectedSection({required this.fmt});
  final MoneyFormatter fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(detectedRecurringProvider);
    final names = ref.watch(merchantNamesProvider).valueOrNull ?? const {};
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (series) {
        if (series.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.space.sm),
              child: Text(
                l10n.recurringDetectedTitle,
                style: context.texts.titleMedium,
              ),
            ),
            for (final s in series)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(names[s.merchantId] ?? s.merchantId),
                  subtitle: Text(
                    l10n.recurringDetectedSubtitle(
                      _frequencyLabel(l10n, s.frequency),
                      s.occurrences,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => _TemplateSheet.show(
                      context,
                      ref,
                      seed: s,
                      seedName: names[s.merchantId],
                    ),
                    child: Text(l10n.recurringCreateFromDetected),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _frequencyLabel(AppLocalizations l10n, RecurringFrequency f) =>
    switch (f) {
      RecurringFrequency.weekly => l10n.recurringWeekly,
      RecurringFrequency.monthly => l10n.recurringMonthly,
      RecurringFrequency.yearly => l10n.recurringYearly,
    };

class _TemplateSheet extends ConsumerStatefulWidget {
  const _TemplateSheet({this.template, this.seed, this.seedName});
  final RecurringTemplateEntity? template;
  final RecurringSeries? seed;
  final String? seedName;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    RecurringTemplateEntity? template,
    RecurringSeries? seed,
    String? seedName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _TemplateSheet(template: template, seed: seed, seedName: seedName),
    );
  }

  @override
  ConsumerState<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends ConsumerState<_TemplateSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  TxType _type = TxType.expense;
  String? _accountId;
  String? _categoryId;
  String? _merchantId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _nextDate = DateTime.now().toUtc();
  bool _active = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    final s = widget.seed;
    if (t != null) {
      _nameCtrl.text = t.name;
      _amountCtrl.text = t.amount.amount.toString();
      _type = t.type;
      _accountId = t.accountId;
      _categoryId = t.categoryId;
      _merchantId = t.merchantId;
      _frequency = t.frequency;
      _nextDate = t.nextDate;
      _active = t.isActive;
    } else if (s != null) {
      _nameCtrl.text = widget.seedName ?? s.merchantId;
      _amountCtrl.text = s.typicalAmount.toString();
      _merchantId = s.merchantId;
      _frequency = s.frequency;
      _nextDate = s.nextExpected;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) throw Exception(l10n.recurringValidationName);
      if (_accountId == null) throw Exception(l10n.recurringValidationAccount);
      if (_categoryId == null) {
        throw Exception(l10n.recurringValidationCategory);
      }
      final amount = Decimal.tryParse(_amountCtrl.text.trim());
      if (amount == null || amount <= Decimal.zero) {
        throw Exception(l10n.recurringValidationAmount);
      }
      final session = ref.read(authServiceProvider).current.session!;
      final base = await ref.read(baseCurrencyProvider.future);
      final service = await ref.read(recurringServiceProvider.future);
      final existing = widget.template;
      await service.upsert(
        RecurringTemplateEntity(
          id: existing?.id ?? const Uuid().v4(),
          userId: session.userId,
          type: _type,
          name: name,
          accountId: _accountId!,
          categoryId: _categoryId!,
          merchantId: _merchantId,
          amount: Money(amount, existing?.amount.currencyCode ?? base),
          frequency: _frequency,
          nextDate: DateTime.utc(
            _nextDate.year,
            _nextDate.month,
            _nextDate.day,
          ),
          lastRunDate: existing?.lastRunDate,
          isActive: _active,
          updatedAt: DateTime.now().toUtc(),
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
    final existing = widget.template;
    if (existing == null) return;
    setState(() => _busy = true);
    final service = await ref.read(recurringServiceProvider.future);
    await service.delete(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate.toLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _nextDate = DateTime.utc(
            picked.year,
            picked.month,
            picked.day,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <AccountEntity>[];
    final categories = (ref.watch(categoriesFlatProvider).valueOrNull ??
            const <CategoryEntity>[])
        .where((c) => !c.isArchived)
        .toList();
    final accountId =
        accounts.any((a) => a.id == _accountId) ? _accountId : null;
    final categoryId =
        categories.any((c) => c.id == _categoryId) ? _categoryId : null;
    final insets = MediaQuery.viewInsetsOf(context);
    final nextLabel = _nextDate.toLocal().toString().split(' ').first;

    return Padding(
      padding: EdgeInsets.only(
        left: context.space.lg,
        right: context.space.lg,
        top: context.space.sm,
        bottom: context.space.lg + insets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.template == null
                  ? l10n.recurringNewTitle
                  : l10n.recurringEditTitle,
              style: context.texts.titleLarge,
            ),
            SizedBox(height: context.space.md),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.recurringName),
            ),
            SizedBox(height: context.space.sm),
            SegmentedButton<TxType>(
              segments: [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text(l10n.categoryExpense),
                ),
                ButtonSegment(
                  value: TxType.income,
                  label: Text(l10n.categoryIncome),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            SizedBox(height: context.space.sm),
            DropdownButtonFormField<String>(
              value: accountId,
              decoration: InputDecoration(labelText: l10n.recurringAccount),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            SizedBox(height: context.space.sm),
            DropdownButtonFormField<String>(
              value: categoryId,
              decoration: InputDecoration(labelText: l10n.recurringCategory),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            SizedBox(height: context.space.sm),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.recurringAmount),
            ),
            SizedBox(height: context.space.sm),
            SegmentedButton<RecurringFrequency>(
              segments: [
                ButtonSegment(
                  value: RecurringFrequency.weekly,
                  label: Text(l10n.recurringWeekly),
                ),
                ButtonSegment(
                  value: RecurringFrequency.monthly,
                  label: Text(l10n.recurringMonthly),
                ),
                ButtonSegment(
                  value: RecurringFrequency.yearly,
                  label: Text(l10n.recurringYearly),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            SizedBox(height: context.space.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.recurringNextDate),
              subtitle: Text(nextLabel),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            if (widget.template != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.recurringActive),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
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
              child:
                  _busy ? const ButtonSpinner() : Text(l10n.recurringSave),
            ),
            if (widget.template != null) ...[
              SizedBox(height: context.space.xs),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: Icon(
                  Icons.delete_outline,
                  color: context.semantic.danger,
                ),
                label: Text(
                  l10n.recurringDelete,
                  style: TextStyle(color: context.semantic.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
