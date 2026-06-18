import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/currency_service.dart';
import '../../core/di/providers.dart';
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
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? const [];
    final categories =
        ref.watch(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit transaction' : 'New transaction'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(context.space.md),
        children: [
          _typeSelector(),
          SizedBox(height: context.space.md),
          _dateTile(context),
          SizedBox(height: context.space.sm),
          ..._accountFields(context, accounts),
          SizedBox(height: context.space.sm),
          _currencyField(currencies),
          if (_currency != _baseCurrency) ...[
            SizedBox(height: context.space.sm),
            _rateField(),
          ],
          SizedBox(height: context.space.md),
          if (_type == TxType.transfer)
            _amountField('Amount')
          else
            _amountOrSplit(context, categories),
          SizedBox(height: context.space.md),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
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
        ],
      ),
    );
  }

  Widget _typeSelector() {
    return SegmentedButton<TxType>(
      segments: const [
        ButtonSegment(value: TxType.expense, label: Text('Expense')),
        ButtonSegment(value: TxType.income, label: Text('Income')),
        ButtonSegment(value: TxType.transfer, label: Text('Transfer')),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(text),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _date = picked);
      },
    );
  }

  List<Widget> _accountFields(
    BuildContext context,
    List<AccountEntity> accounts,
  ) {
    if (_type == TxType.transfer) {
      return [
        _accountDropdown(
          accounts,
          label: 'From account',
          value: _accountId,
          onChanged: (v) => setState(() => _accountId = v),
        ),
        SizedBox(height: context.space.sm),
        _accountDropdown(
          accounts,
          label: 'To account',
          value: _counterAccountId,
          onChanged: (v) => setState(() => _counterAccountId = v),
        ),
      ];
    }
    return [
      _accountDropdown(
        accounts,
        label: 'Account',
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
    final exists = currencies.any((c) => c.code == _currency);
    return DropdownButtonFormField<String>(
      value: exists ? _currency : null,
      decoration: const InputDecoration(labelText: 'Currency'),
      items: [
        for (final c in currencies)
          DropdownMenuItem(value: c.code, child: Text('${c.code} — ${c.name}')),
      ],
      onChanged: (v) => setState(() => _currency = v ?? _baseCurrency),
    );
  }

  Widget _rateField() {
    return TextField(
      controller: _rateCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Exchange rate (1 $_currency = ? $_baseCurrency)',
        helperText: 'Leave blank to use a saved rate for this date',
      ),
    );
  }

  Widget _amountOrSplit(BuildContext context, List<CategoryEntity> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Split into items', style: context.texts.titleSmall),
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
    final selected = categoryById(categories, _quickCategoryId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _amountField('Amount'),
        SizedBox(height: context.space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: selected == null
              ? OutlinedButton.icon(
                  onPressed: _pickQuickCategory,
                  icon: const Icon(Icons.label_outline),
                  label: const Text('Choose category'),
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
          label: const Text('Add item'),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: context.texts.titleSmall),
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
                  decoration: const InputDecoration(labelText: 'Description'),
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
                  decoration: const InputDecoration(labelText: 'Amount'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
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
              label: Text(selected?.name ?? 'Category'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField(String label) {
    return TextField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  Decimal? _parse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final d = Decimal.tryParse(cleaned);
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
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doSave() async {
    if (_accountId == null) throw const _ValidationError('Choose an account.');
    if (_type == TxType.transfer) {
      if (_counterAccountId == null) {
        throw const _ValidationError('Choose a destination account.');
      }
      if (_counterAccountId == _accountId) {
        throw const _ValidationError('Transfer needs two different accounts.');
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
      totalDec =
          _parse(_amountCtrl.text) ??
          (throw const _ValidationError('Enter an amount.'));
      lines = const [];
    } else if (_split) {
      if (_lines.isEmpty) {
        throw const _ValidationError('Add at least one item.');
      }
      final built = <LineItemEntity>[];
      var i = 0;
      for (final l in _lines) {
        final amt = _parse(l.amountCtrl.text);
        if (amt == null) {
          throw const _ValidationError('Each item needs a positive amount.');
        }
        if (l.categoryId == null) {
          throw const _ValidationError('Each item needs a category.');
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
      totalDec =
          _parse(_amountCtrl.text) ??
          (throw const _ValidationError('Enter an amount.'));
      if (_quickCategoryId == null) {
        throw const _ValidationError('Choose a category.');
      }
      lines = [
        LineItemEntity(
          id: _originalLineIds.length == 1
              ? _originalLineIds.first
              : _uuid.v4(),
          userId: session.userId,
          transactionId: txId,
          description: _noteCtrl.text.trim().isEmpty
              ? 'Item'
              : _noteCtrl.text.trim(),
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
    final removed = _originalLineIds
        .where((id) => !finalLineIds.contains(id))
        .toList();

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
    var conv = await currencySvc.toBase(total, _date);
    if (conv.needsRate) {
      final rate = _parse(_rateCtrl.text);
      if (rate == null) {
        throw _ValidationError(
          'Enter an exchange rate for $_currency → $_baseCurrency.',
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
