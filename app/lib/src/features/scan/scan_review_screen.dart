import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/currency_service.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/currency.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../../domain/scan/document_draft.dart';
import '../../domain/scan/draft_mapper.dart';
import '../categories/category_picker.dart';
import '../categories/category_visuals.dart';
import '../transactions/capture_providers.dart';
import 'ocr_overlay.dart';
import 'scan_review_controller.dart';

/// Scan review screen (docs/06 §2.5, FR-SCAN-06/11): the original document with
/// OCR overlays beside an editable extracted form. Split view on wide screens,
/// stacked on mobile. Low-confidence fields are flagged; the footer shows
/// reconciliation. Nothing is saved until the user confirms — on save the
/// reviewed draft maps to a Transaction + line items (docs/05 §8).
class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({required this.draft, this.imageBytes, super.key});

  final DocumentDraft draft;
  final Uint8List? imageBytes;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  static const _uuid = Uuid();
  static const _wideBreakpoint = 720.0;

  late final ScanReviewController _c;
  final _merchantCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _lineCtrls = <(TextEditingController, TextEditingController)>[];

  String? _accountId;
  String _baseCurrency = '';
  bool _loaded = false;
  bool _busy = false;
  String? _error;
  String? _highlight; // selected field text → OCR overlay highlight

  @override
  void initState() {
    super.initState();
    _c = ScanReviewController(widget.draft);
    _merchantCtrl.text = _c.merchant;
    _totalCtrl.text = _c.total?.toString() ?? '';
    for (final l in _c.lines) {
      _lineCtrls.add((
        TextEditingController(text: l.description),
        TextEditingController(text: l.amount.toString()),
      ));
    }
    _init();
  }

  @override
  void dispose() {
    _c.dispose();
    _merchantCtrl.dispose();
    _totalCtrl.dispose();
    for (final (d, a) in _lineCtrls) {
      d.dispose();
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _baseCurrency = await ref.read(baseCurrencyProvider.future);
    if (_c.currencyCode.isEmpty) _c.setCurrency(_baseCurrency);
    final accounts = await ref.read(accountsProvider.future);
    if (accounts.isNotEmpty) _accountId = accounts.first.id;
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanReviewTitle),
        actions: [
          _docTypeMenu(),
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const ButtonSpinner() : Text(l10n.scanReviewSave),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(context.space.md),
                    child: _imagePane(context),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Image is in the left pane already → don't repeat it inline.
                Expanded(child: _formPane(context, showInlineImage: false)),
              ],
            );
          }
          return _formPane(context, showInlineImage: true);
        },
      ),
    );
  }

  // --- image / OCR pane --------------------------------------------------

  Widget _imagePane(BuildContext context) {
    final bytes = widget.imageBytes;
    final ocr = widget.draft.ocr;
    if (bytes != null && ocr != null) {
      return SingleChildScrollView(
        child: OcrOverlay(ocr: ocr, imageBytes: bytes, highlight: _highlight),
      );
    }
    // No image preview yet (ingest lands later): show the raw OCR text so the
    // user can still cross-reference while correcting fields (docs/05 §6).
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 18, color: context.colors.onSurfaceVariant),
                SizedBox(width: context.space.xs),
                Text(AppLocalizations.of(context).scanRecognizedText,
                    style: context.texts.titleSmall),
              ],
            ),
            SizedBox(height: context.space.sm),
            SelectableText(
              ocr?.fullText.trim().isNotEmpty ?? false
                  ? ocr!.fullText
                  : AppLocalizations.of(context).scanNoPreview,
              style: context.texts.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // --- form pane ---------------------------------------------------------

  Widget _formPane(BuildContext context, {required bool showInlineImage}) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => ListView(
        padding: EdgeInsets.all(context.space.md),
        children: [
          if (showInlineImage && widget.draft.ocr != null) ...[
            _imagePane(context),
            SizedBox(height: context.space.md),
          ],
          _accountDropdown(accounts),
          SizedBox(height: context.space.sm),
          _currencyDropdown(currencies),
          SizedBox(height: context.space.md),
          _merchantField(context),
          SizedBox(height: context.space.sm),
          _dateField(context),
          SizedBox(height: context.space.sm),
          _totalField(context),
          SizedBox(height: context.space.md),
          Text(l10n.scanLineItems, style: context.texts.titleSmall),
          SizedBox(height: context.space.xs),
          for (var i = 0; i < _c.lines.length; i++)
            _lineRow(context, i, categories),
          TextButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add),
            label: Text(l10n.scanAddItem),
          ),
          const Divider(),
          _reconciliationRow(context),
          if (_error != null) ...[
            SizedBox(height: context.space.sm),
            Text(
              _error!,
              style: context.texts.bodySmall
                  ?.copyWith(color: context.semantic.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountDropdown(List<AccountEntity> accounts) {
    final l10n = AppLocalizations.of(context);
    final exists = accounts.any((a) => a.id == _accountId);
    return DropdownButtonFormField<String>(
      value: exists ? _accountId : null,
      decoration: InputDecoration(labelText: l10n.scanAccount),
      items: [
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text('${a.name} (${a.currencyCode})'),
          ),
      ],
      onChanged: (v) => setState(() => _accountId = v),
    );
  }

  Widget _currencyDropdown(List<CurrencyEntity> currencies) {
    final l10n = AppLocalizations.of(context);
    final exists = currencies.any((c) => c.code == _c.currencyCode);
    return DropdownButtonFormField<String>(
      value: exists ? _c.currencyCode : null,
      decoration: InputDecoration(
        labelText: l10n.scanCurrency,
        suffixIcon: _confidenceDot('currency'),
      ),
      items: [
        for (final c in currencies)
          DropdownMenuItem(value: c.code, child: Text('${c.code} — ${c.name}')),
      ],
      onChanged: (v) => _c.setCurrency(v ?? _baseCurrency),
    );
  }

  Widget _merchantField(BuildContext context) {
    return TextField(
      controller: _merchantCtrl,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).scanMerchant,
        suffixIcon: _confidenceDot('merchant'),
      ),
      onChanged: _c.setMerchant,
      onTap: () => setState(() => _highlight = _merchantCtrl.text.trim()),
    );
  }

  Widget _dateField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = _c.date;
    final text =
        d == null ? l10n.scanNoDate : '${d.year}-${_2(d.month)}-${_2(d.day)}';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.scanDate,
        suffixIcon: _confidenceDot('date'),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: d ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) _c.setDate(picked);
            },
            child: Text(l10n.scanChange),
          ),
        ],
      ),
    );
  }

  Widget _totalField(BuildContext context) {
    return TextField(
      controller: _totalCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).scanTotal,
        suffixIcon: _confidenceDot('total'),
      ),
      onChanged: (v) => _c.setTotal(_parse(v)),
      onTap: () => setState(() => _highlight = _totalCtrl.text.trim()),
    );
  }

  Widget _lineRow(
    BuildContext context,
    int i,
    List<CategoryEntity> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final (descCtrl, amountCtrl) = _lineCtrls[i];
    final line = _c.lines[i];
    final selected = categoryById(categories, line.categoryId);
    final lowCat =
        (line.categoryConfidence ?? 1.0) < ScanReviewController.lowConfidence;
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
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: l10n.scanDescription),
                  onChanged: (v) => _c.setLineDescription(i, v),
                  onTap: () =>
                      setState(() => _highlight = descCtrl.text.trim()),
                ),
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.scanAmount),
                  onChanged: (v) =>
                      _c.setLineAmount(i, _parse(v) ?? Decimal.zero),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.scanRemoveItem,
                onPressed: () => _removeLine(i),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pickCategory(i),
              icon: Icon(
                selected == null
                    ? Icons.label_outline
                    : categoryIcon(selected.icon),
                color: lowCat ? context.semantic.warning : null,
              ),
              label: Text(selected?.name ?? l10n.scanCategory),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reconciliationRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balanced = _c.isReconciled;
    final hasLines = _c.lines.isNotEmpty;
    final delta = _c.reconciliationDelta;
    final color = !hasLines
        ? context.texts.bodySmall?.color
        : balanced
            ? context.semantic.success
            : context.semantic.warning;
    final label = !hasLines
        ? l10n.scanReconcileNoLineItems
        : balanced
            ? l10n.scanReconcileBalanced
            : l10n.scanReconcileMismatch(
                  '${_c.lineSum}',
                  '${_c.total ?? '—'}',
                ) +
                (delta == null ? '' : l10n.scanReconcileDelta('$delta'));
    return Row(
      children: [
        Icon(
          !hasLines
              ? Icons.info_outline
              : balanced
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
          size: 18,
          color: color,
        ),
        SizedBox(width: context.space.xs),
        Expanded(
          child: Text(label,
              style: context.texts.bodySmall?.copyWith(color: color)),
        ),
      ],
    );
  }

  Widget _docTypeMenu() {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<DocType>(
      initialValue: _c.docType,
      tooltip: l10n.scanDocumentType,
      onSelected: _c.setDocType,
      itemBuilder: (_) => [
        for (final t in DocType.values)
          PopupMenuItem(value: t, child: Text(_docTypeLabel(l10n, t))),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.space.xs),
        child: Row(
          children: [
            Text(_docTypeLabel(l10n, _c.docType)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  /// A coloured dot conveying field confidence (icon + colour, not colour alone).
  Widget? _confidenceDot(String key) {
    final low = _c.isFieldLow(key);
    final c = _c.fieldConfidence(key);
    if (c == null) return null;
    final l10n = AppLocalizations.of(context);
    return Icon(
      low ? Icons.error_outline : Icons.check_circle,
      size: 18,
      color: low ? context.semantic.warning : context.semantic.success,
      semanticLabel: low ? l10n.scanLowConfidence : l10n.scanHighConfidence,
    );
  }

  // --- actions -----------------------------------------------------------

  Future<void> _pickCategory(int i) async {
    final kind = _c.docType == DocType.paycheck
        ? CategoryKind.income
        : CategoryKind.expense;
    final id = await showCategoryPicker(context, kind: kind);
    if (id != null) _c.setLineCategory(i, id);
  }

  void _addLine() {
    _c.addLine();
    setState(() => _lineCtrls.add((
          TextEditingController(),
          TextEditingController(text: '0'),
        )));
  }

  void _removeLine(int i) {
    final (d, a) = _lineCtrls.removeAt(i);
    d.dispose();
    a.dispose();
    _c.removeLine(i);
    setState(() {});
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _doSave();
      if (mounted) Navigator.of(context).maybePop(true);
    } on _ReviewError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doSave() async {
    final l10n = AppLocalizations.of(context);
    final accountId = _accountId;
    if (accountId == null) {
      throw _ReviewError(l10n.scanValidationChooseAccount);
    }
    final total = _c.total;
    if (total == null && _c.lines.isEmpty) {
      throw _ReviewError(l10n.scanValidationEnterTotalOrItem);
    }
    final currency = _c.currencyCode;
    if (currency.isEmpty) throw _ReviewError(l10n.scanValidationChooseCurrency);

    final session = ref.read(authServiceProvider).current.session;
    if (session == null) throw _ReviewError(l10n.scanValidationNotSignedIn);

    final categories = ref.read(categoriesFlatProvider).valueOrNull ??
        const <CategoryEntity>[];
    final fallback = _fallbackCategory(categories);
    if (fallback == null) {
      throw _ReviewError(l10n.scanValidationNoCategory);
    }

    final txSvc = await ref.read(transactionServiceProvider.future);
    final currencySvc = await ref.read(currencyServiceProvider.future);

    final date = _c.date ?? DateTime.now();
    final money = Money(total ?? _c.lineSum, currency);
    final base = await _resolveBase(money, date, currency, currencySvc);

    final now = DateTime.now().toUtc();
    final mapping = _c.buildMapping(
      DraftMappingContext(
        userId: session.userId,
        accountId: accountId,
        currencyCode: currency,
        base: base,
        fallbackCategoryId: fallback,
        newId: _uuid.v4,
        now: now,
      ),
    );
    await txSvc.upsertWithLines(mapping.header, mapping.lines);
    await _saveAttachment(mapping.header.id);
    await _learnMerchantTemplate();
  }

  /// Remember this merchant's currency, document type, and per-item categories
  /// so future scans from the same merchant extract better (FR-SCAN-10).
  /// Best-effort: a learning failure must never fail the (already-saved) scan.
  Future<void> _learnMerchantTemplate() async {
    final merchant = _c.merchant.trim();
    if (merchant.isEmpty) return;
    try {
      final hints = <String, String>{
        for (final l in _c.lines)
          if (l.categoryId != null && l.description.trim().isNotEmpty)
            l.description: l.categoryId!,
      };
      final service = await ref.read(merchantTemplateServiceProvider.future);
      await service.learnFromScan(
        merchant: merchant,
        currencyCode: _c.currencyCode.isEmpty ? null : _c.currencyCode,
        docType: _c.docType,
        descriptionToCategory: hints,
      );
      // Rebuild the pipeline so the next scan applies the updated template.
      ref.invalidate(scanServiceProvider);
      ref.invalidate(scanCoordinatorProvider);
    } on Exception {
      // Swallow — learning is an optimization, not part of the save contract.
    }
  }

  /// When the scan carried an image, store it client-side encrypted and link the
  /// metadata to the new transaction (docs/05 §8, FR-SCAN-08).
  Future<void> _saveAttachment(String transactionId) async {
    final bytes = widget.imageBytes;
    if (bytes == null) return;
    final store = await ref.read(attachmentStoreProvider.future);
    final attachments = await ref.read(attachmentServiceProvider.future);
    final attachment = await store.save(
      bytes: bytes,
      fileName: '$transactionId.jpg',
      docType: _c.docType,
      transactionId: transactionId,
      ocrText: widget.draft.ocr?.fullText,
    );
    await attachments.upsert(attachment);
  }

  Future<Money> _resolveBase(
    Money money,
    DateTime date,
    String currency,
    CurrencyService currencySvc,
  ) async {
    if (currency == _baseCurrency) return money;
    final l10n = AppLocalizations.of(context);
    final conv = await currencySvc.toBase(money, date);
    final base = conv.base;
    if (conv.needsRate || base == null) {
      throw _ReviewError(
        l10n.scanValidationNoRate(currency, _baseCurrency),
      );
    }
    return base;
  }

  String? _fallbackCategory(List<CategoryEntity> categories) {
    final kind = _c.docType == DocType.paycheck
        ? CategoryKind.income
        : CategoryKind.expense;
    final ofKind = categories.where((c) => c.kind == kind && !c.isArchived);
    if (ofKind.isEmpty) return null;
    for (final wanted in ['Misc', 'Income']) {
      for (final c in ofKind) {
        if (c.name == wanted) return c.id;
      }
    }
    return ofKind.first.id;
  }

  Decimal? _parse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return Decimal.tryParse(cleaned);
  }

  String _2(int n) => n.toString().padLeft(2, '0');

  String _docTypeLabel(AppLocalizations l10n, DocType t) => switch (t) {
        DocType.receipt => l10n.scanDocTypeReceipt,
        DocType.invoice => l10n.scanDocTypeInvoice,
        DocType.bill => l10n.scanDocTypeBill,
        DocType.paycheck => l10n.scanDocTypePaycheck,
        DocType.other => l10n.scanDocTypeOther,
      };
}

class _ReviewError implements Exception {
  const _ReviewError(this.message);
  final String message;
}
