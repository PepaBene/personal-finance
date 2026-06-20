import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/currency_service.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/money_formatter.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/line_item.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../categories/category_picker.dart';
import '../categories/category_visuals.dart';
import 'capture_providers.dart';

/// Add/edit a transaction (FR-CAP-01..05, FR-CAT-04, FR-ACC-03, FR-CUR).
///
/// Quick mode = one amount + one category (fast capture, P6). "Split into items"
/// reveals the multi-category line-item editor (P5). Transfers move money
/// between accounts with no category (FR-ACC-03). Foreign-currency entries
/// convert to base using a saved or manually-entered rate (FR-CUR-02..04).
class TransactionEditorScreen extends ConsumerStatefulWidget {
  const TransactionEditorScreen({this.transactionId, super.key});

  final String? transactionId;
  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionEditorScreen> createState() =>
      _TransactionEditorScreenState();
}

class _LineDraft {
  _LineDraft({required this.id, this.existing = false});
  final String id;
  final bool existing;
  final descCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  String? categoryId;

  void dispose() {
    descCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _TransactionEditorScreenState
    extends ConsumerState<TransactionEditorScreen> {
  static const _uuid = Uuid();

  final _noteCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  TxType _type = TxType.expense;
  DateTime _date = DateTime.now();
  String? _accountId;
  String? _counterAccountId;
  String _currency = '';
  String _baseCurrency = '';
  bool _split = false;
  String? _quickCategoryId;
  final List<_LineDraft> _lines = [];
  final List<String> _originalLineIds = [];

  DateTime? _createdAt;
  int _version = 0;
  bool _loaded = false;
  bool _busy = false;
  bool _fetchingRate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _baseCurrency = await ref.read(baseCurrencyProvider.future);
    _currency = _baseCurrency;

    if (widget.isEditing) {
      final service = await ref.read(transactionServiceProvider.future);
      final header = await service.getById(widget.transactionId!);
      final lines = await service.watchLineItems(widget.transactionId!).first;
      if (header != null) {
        _type = header.type;
        _date = header.date.toLocal();
        _accountId = header.accountId;
        _counterAccountId = header.counterAccountId;
        _currency = header.total.currencyCode;
        _noteCtrl.text = header.note ?? '';
        _createdAt = header.createdAt;
        _version = header.version;
        _originalLineIds.addAll(lines.map((l) => l.id));

        if (_type != TxType.transfer && lines.length > 1) {
          _split = true;
          for (final l in lines) {
            _lines.add(
              _LineDraft(id: l.id, existing: true)
                ..descCtrl.text = l.description
                ..amountCtrl.text = l.lineAmount.amount.toString()
                ..categoryId = l.categoryId,
            );
          }
        } else {
          _amountCtrl.text = header.total.amount.toString();
          if (lines.isNotEmpty) _quickCategoryId = lines.first.categoryId;
        }
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? l10n.transactionEditorEditTitle
              : l10n.transactionEditorNewTitle,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.space.contentMaxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.space.md,
              context.space.md,
              context.space.md,
              context.space.xxxl,
            ),
            children: [
              _typeSelector(),
              SizedBox(height: context.space.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: l10n.transactionAccount),
                    SizedBox(height: context.space.md),
                    _dateTile(context),
                    SizedBox(height: context.space.md),
                    ..._withGaps(_accountFields(context, accounts)),
                    SizedBox(height: context.space.md),
                    _currencyField(currencies),
                    if (_currency != _baseCurrency) ...[
                      SizedBox(height: context.space.md),
                      _rateField(),
                    ],
                  ],
                ),
              ),
              SizedBox(height: context.space.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: l10n.transactionAmount),
                    SizedBox(height: context.space.md),
                    if (_type == TxType.transfer)
                      _amountField(l10n.transactionAmount, prominent: true)
                    else
                      _amountOrSplit(context, categories),
                  ],
                ),
              ),
              SizedBox(height: context.space.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: l10n.transactionNote),
                    SizedBox(height: context.space.md),
                    TextField(
                      controller: _noteCtrl,
                      decoration:
                          InputDecoration(labelText: l10n.transactionNote),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: context.space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: context.semantic.danger,
                    ),
                    SizedBox(width: context.space.xs),
                    Expanded(
                      child: Text(
                        _error!,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.semantic.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: context.space.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const ButtonSpinner()
                    : Text(l10n.transactionEditorSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Inserts vertical [context.space.md] gaps between a list of field widgets.
  List<Widget> _withGaps(List<Widget> widgets) {
    final out = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) out.add(SizedBox(height: context.space.md));
      out.add(widgets[i]);
    }
    return out;
  }

  Widget _typeSelector() {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<TxType>(
      segments: [
        ButtonSegment(
          value: TxType.expense,
          label: Text(l10n.transactionTypeExpense),
        ),
        ButtonSegment(
          value: TxType.income,
          label: Text(l10n.transactionTypeIncome),
        ),
        ButtonSegment(
          value: TxType.transfer,
          label: Text(l10n.transactionTypeTransfer),
        ),
      ],
      selected: {_type},
      onSelectionChanged: (s) => setState(() {
        _type = s.first;
        if (_type == TxType.transfer) _split = false;
      }),
    );
  }

  Widget _dateTile(BuildContext context) {
    final d = _date;
    final text =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: context.radii.mdRadius,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.event_outlined),
          suffixIcon: Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(text, style: context.texts.bodyLarge),
      ),
    );
  }

  List<Widget> _accountFields(
    BuildContext context,
    List<AccountEntity> accounts,
  ) {
    final l10n = AppLocalizations.of(context);
    if (_type == TxType.transfer) {
      return [
        _accountDropdown(
          accounts,
          label: l10n.transactionFromAccount,
          value: _accountId,
          onChanged: (v) => setState(() => _accountId = v),
        ),
        SizedBox(height: context.space.sm),
        _accountDropdown(
          accounts,
          label: l10n.transactionToAccount,
          value: _counterAccountId,
          onChanged: (v) => setState(() => _counterAccountId = v),
        ),
      ];
    }
    return [
      _accountDropdown(
        accounts,
        label: l10n.transactionAccount,
        value: _accountId,
        onChanged: (v) => setState(() => _accountId = v),
      ),
    ];
  }

  Widget _accountDropdown(
    List<AccountEntity> accounts, {
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final exists = accounts.any((a) => a.id == value);
    return DropdownButtonFormField<String>(
      value: exists ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text('${a.name} (${a.currencyCode})'),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _currencyField(List<CurrencyEntity> currencies) {
    final l10n = AppLocalizations.of(context);
    final exists = currencies.any((c) => c.code == _currency);
    return DropdownButtonFormField<String>(
      value: exists ? _currency : null,
      decoration: InputDecoration(labelText: l10n.transactionCurrency),
      items: [
        for (final c in currencies)
          DropdownMenuItem(value: c.code, child: Text('${c.code} — ${c.name}')),
      ],
      onChanged: (v) => setState(() => _currency = v ?? _baseCurrency),
    );
  }

  Widget _rateField() {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _rateCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: l10n.transactionExchangeRateLabel(_currency, _baseCurrency),
        helperText: l10n.transactionExchangeRateHelper,
        suffixIcon: IconButton(
          tooltip: l10n.transactionFetchRate,
          icon: _fetchingRate
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download_outlined),
          onPressed: _fetchingRate ? null : _fetchRate,
        ),
      ),
    );
  }

  /// Opt-in online rate fetch (FR-CUR-05): fills the rate field from a one-off
  /// online lookup for the chosen date. Never required — manual entry remains.
  Future<void> _fetchRate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetchingRate = true);
    try {
      final currencySvc = await ref.read(currencyServiceProvider.future);
      final rate = await currencySvc.fetchOnlineRate(
        fromCode: _currency,
        toCode: _baseCurrency,
        date: _date,
      );
      if (mounted) {
        setState(() => _rateCtrl.text = rate.toString());
      }
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.transactionFetchRateFailed(friendlyError(e)))),
      );
    } finally {
      if (mounted) setState(() => _fetchingRate = false);
    }
  }

  Widget _amountOrSplit(BuildContext context, List<CategoryEntity> categories) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.transactionSplitIntoItems,
                style: context.texts.titleSmall,
              ),
            ),
            Switch(
              value: _split,
              onChanged: (v) => setState(() {
                _split = v;
                if (v && _lines.isEmpty) {
                  final seed = _LineDraft(id: _uuid.v4())
                    ..categoryId = _quickCategoryId;
                  if (_amountCtrl.text.isNotEmpty) {
                    seed.amountCtrl.text = _amountCtrl.text;
                  }
                  _lines.add(seed);
                }
              }),
            ),
          ],
        ),
        if (!_split)
          _quickFields(context, categories)
        else
          _splitEditor(context, categories),
      ],
    );
  }

  Widget _quickFields(BuildContext context, List<CategoryEntity> categories) {
    final l10n = AppLocalizations.of(context);
    final selected = categoryById(categories, _quickCategoryId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _amountField(l10n.transactionAmount, prominent: true),
        SizedBox(height: context.space.md),
        Align(
          alignment: Alignment.centerLeft,
          child: selected == null
              ? OutlinedButton.icon(
                  onPressed: _pickQuickCategory,
                  icon: const Icon(Icons.label_outline),
                  label: Text(l10n.transactionChooseCategory),
                )
              : CategoryChip(
                  label: selected.name,
                  color: categoryColor(selected.colorHex),
                  icon: categoryIcon(selected.icon),
                  onTap: _pickQuickCategory,
                ),
        ),
      ],
    );
  }

  Future<void> _pickQuickCategory() async {
    final id = await showCategoryPicker(context, kind: _categoryKind);
    if (id != null) setState(() => _quickCategoryId = id);
  }

  CategoryKind get _categoryKind =>
      _type == TxType.income ? CategoryKind.income : CategoryKind.expense;

  Widget _splitEditor(BuildContext context, List<CategoryEntity> categories) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sum = _linesSum();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in _lines) _lineRow(context, line, categories),
        TextButton.icon(
          onPressed: () =>
              setState(() => _lines.add(_LineDraft(id: _uuid.v4()))),
          icon: const Icon(Icons.add),
          label: Text(l10n.transactionAddItem),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.transactionTotal, style: context.texts.titleSmall),
            MoneyText(
              formattedAmount: MoneyFormatter(
                locale,
              ).format(Money(sum, _currency)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lineRow(
    BuildContext context,
    _LineDraft line,
    List<CategoryEntity> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final selected = categoryById(categories, line.categoryId);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.xxs),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: line.descCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.transactionDescription,
                  ),
                ),
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: line.amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      InputDecoration(labelText: l10n.transactionAmount),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.transactionRemoveItem,
                onPressed: () => setState(() {
                  if (line.existing) _originalLineIds.remove(line.id);
                  _lines.remove(line);
                  line.dispose();
                }),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final id = await showCategoryPicker(
                  context,
                  kind: _categoryKind,
                );
                if (id != null) setState(() => line.categoryId = id);
              },
              icon: Icon(
                selected == null
                    ? Icons.label_outline
                    : categoryIcon(selected.icon),
              ),
              label: Text(selected?.name ?? l10n.transactionCategory),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField(String label, {bool prominent = false}) {
    return TextField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: prominent ? TextAlign.center : TextAlign.start,
      style: prominent
          ? AppTypography.moneyStyle(36, useDisplay: true).copyWith(
              color: context.colors.onSurface,
            )
          : null,
      decoration: InputDecoration(labelText: label),
    );
  }

  Decimal _linesSum() {
    var sum = Decimal.zero;
    for (final l in _lines) {
      sum += _parse(l.amountCtrl.text) ?? Decimal.zero;
    }
    return sum;
  }

  /// Tolerant amount parse: drops spaces/NBSP grouping and handles both
  /// comma-decimal and dot-decimal input (the last separator is the decimal
  /// point; the other groups thousands).
  Decimal? _parse(String text) {
    var s = text.trim().replaceAll(RegExp(r'[\s ]'), '');
    if (s.isEmpty) return null;
    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      s = s.lastIndexOf(',') > s.lastIndexOf('.')
          ? s.replaceAll('.', '').replaceAll(',', '.') // comma is the decimal
          : s.replaceAll(',', ''); // dot is the decimal, comma groups
    } else if (hasComma) {
      s = s.replaceAll(',', '.'); // single comma = decimal separator
    }
    final d = Decimal.tryParse(s);
    return (d == null || d <= Decimal.zero) ? null : d;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _doSave();
      if (mounted) Navigator.of(context).pop();
    } on _ValidationError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doSave() async {
    final l10n = AppLocalizations.of(context);
    if (_accountId == null) {
      throw _ValidationError(l10n.transactionValidationChooseAccount);
    }
    if (_type == TxType.transfer) {
      if (_counterAccountId == null) {
        throw _ValidationError(l10n.transactionValidationChooseDestination);
      }
      if (_counterAccountId == _accountId) {
        throw _ValidationError(l10n.transactionValidationDifferentAccounts);
      }
    }

    final session = ref.read(authServiceProvider).current.session!;
    final txSvc = await ref.read(transactionServiceProvider.future);
    final currencySvc = await ref.read(currencyServiceProvider.future);

    final txId = widget.transactionId ?? _uuid.v4();
    final now = DateTime.now().toUtc();

    final Decimal totalDec;
    final List<LineItemEntity> lines;

    if (_type == TxType.transfer) {
      totalDec = _parse(_amountCtrl.text) ??
          (throw _ValidationError(l10n.transactionValidationEnterAmount));
      lines = const [];
    } else if (_split) {
      if (_lines.isEmpty) {
        throw _ValidationError(l10n.transactionValidationAddItem);
      }
      final built = <LineItemEntity>[];
      var i = 0;
      for (final l in _lines) {
        final amt = _parse(l.amountCtrl.text);
        if (amt == null) {
          throw _ValidationError(
            l10n.transactionValidationItemPositiveAmount,
          );
        }
        if (l.categoryId == null) {
          throw _ValidationError(l10n.transactionValidationItemCategory);
        }
        built.add(
          LineItemEntity(
            id: l.id,
            userId: session.userId,
            transactionId: txId,
            description: l.descCtrl.text.trim().isEmpty
                ? 'Item'
                : l.descCtrl.text.trim(),
            quantity: Decimal.one,
            lineAmount: Money(amt, _currency),
            categoryId: l.categoryId!,
            sortOrder: i++,
            updatedAt: now,
          ),
        );
      }
      lines = built;
      totalDec = built.fold(Decimal.zero, (s, l) => s + l.lineAmount.amount);
    } else {
      totalDec = _parse(_amountCtrl.text) ??
          (throw _ValidationError(l10n.transactionValidationEnterAmount));
      if (_quickCategoryId == null) {
        throw _ValidationError(l10n.transactionValidationChooseCategory);
      }
      lines = [
        LineItemEntity(
          id: _originalLineIds.length == 1
              ? _originalLineIds.first
              : _uuid.v4(),
          userId: session.userId,
          transactionId: txId,
          description:
              _noteCtrl.text.trim().isEmpty ? 'Item' : _noteCtrl.text.trim(),
          quantity: Decimal.one,
          lineAmount: Money(totalDec, _currency),
          categoryId: _quickCategoryId!,
          updatedAt: now,
        ),
      ];
    }

    final total = Money(totalDec, _currency);
    final base = await _resolveBase(total, currencySvc);

    final finalLineIds = lines.map((l) => l.id).toSet();
    final removed =
        _originalLineIds.where((id) => !finalLineIds.contains(id)).toList();

    final header = TransactionEntity(
      id: txId,
      userId: session.userId,
      type: _type,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      accountId: _accountId!,
      counterAccountId: _type == TxType.transfer ? _counterAccountId : null,
      total: total,
      base: base,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: _createdAt ?? now,
      updatedAt: now,
      version: _version,
    );

    await txSvc.upsertWithLines(header, lines, removedLineItemIds: removed);
  }

  Future<Money> _resolveBase(Money total, CurrencyService currencySvc) async {
    if (_currency == _baseCurrency) return total;
    final l10n = AppLocalizations.of(context);
    var conv = await currencySvc.toBase(total, _date);
    if (conv.needsRate) {
      final rate = _parse(_rateCtrl.text);
      if (rate == null) {
        throw _ValidationError(
          l10n.transactionValidationEnterRate(_currency, _baseCurrency),
        );
      }
      await currencySvc.upsertRate(
        fromCode: _currency,
        toCode: _baseCurrency,
        rate: rate,
        date: _date,
      );
      conv = await currencySvc.toBase(total, _date);
    }
    return conv.base!;
  }
}

class _ValidationError implements Exception {
  const _ValidationError(this.message);
  final String message;
}
