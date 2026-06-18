import 'package:csv/csv.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../application/auth_service.dart';
import '../../application/currency_service.dart';
import '../../application/import_export_service.dart';
import '../../application/transaction_service.dart';
import '../../domain/entities/line_item.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed CSV import/export (FR-DAT-04/05). Export is line-level with a
/// `transaction_id` so splits regroup on re-import. Import matches categories
/// and accounts by name (creating missing ones) and reuses the transaction
/// service so sync columns/invariants are handled uniformly.
class DriftImportExportService implements ImportExportService {
  DriftImportExportService(this._db, this._auth, this._tx, this._currency);

  final db.AppDatabase _db;
  final AuthService _auth;
  final TransactionService _tx;
  final CurrencyService _currency;
  static const _uuid = Uuid();

  static const _header = [
    'transaction_id',
    'date',
    'type',
    'account',
    'counter_account',
    'currency',
    'total',
    'base',
    'note',
    'line_description',
    'line_amount',
    'category',
  ];

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  // --- export ------------------------------------------------------------

  @override
  Future<String> exportCsv() async {
    final txs = await (_db.select(_db.transactions)
          ..where((t) => t.userId.equals(_userId) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    final accountNames = {
      for (final a in await _db.watchAccounts(_userId).first) a.id: a.name,
    };
    final categoryNames = {
      for (final c in await _db.watchCategories(_userId).first) c.id: c.name,
    };

    final rows = <List<String>>[_header];
    for (final t in txs) {
      final lines = await _db.getLineItems(t.id);
      final dateStr = _fmtDate(t.date);
      final commonHead = [
        t.id,
        dateStr,
        t.type.name,
        accountNames[t.accountId] ?? '',
        accountNames[t.counterAccountId] ?? '',
        t.currencyCode,
        t.totalAmount.toString(),
        t.baseAmount.toString(),
        t.note ?? '',
      ];
      if (lines.isEmpty) {
        rows.add([...commonHead, '', t.totalAmount.toString(), '']);
      } else {
        for (final l in lines) {
          rows.add([
            ...commonHead,
            l.description,
            l.lineAmount.toString(),
            categoryNames[l.categoryId] ?? '',
          ]);
        }
      }
    }
    return ListToCsvConverter().convert(rows);
  }

  // --- import ------------------------------------------------------------

  @override
  Future<ImportReport> importCsv(String csv) async {
    final table = CsvToListConverter(shouldParseNumbers: false).convert(csv);
    if (table.length < 2) {
      return const ImportReport(imported: 0, skipped: 0, errors: ['Empty CSV']);
    }
    final idx = <String, int>{};
    final headerRow = table.first;
    for (var i = 0; i < headerRow.length; i++) {
      idx[headerRow[i].toString().trim().toLowerCase()] = i;
    }

    final categoriesByName = <String, db.Category>{
      for (final c in await _db.watchCategories(_userId).first)
        c.name.toLowerCase(): c,
    };
    final accountsByName = <String, db.Account>{
      for (final a in await _db.watchAccounts(_userId).first)
        a.name.toLowerCase(): a,
    };
    final baseCurrency = await _currency.baseCurrencyCode();

    // Group data rows by transaction_id (blank → unique per row).
    final groups = <String, List<List<dynamic>>>{};
    final order = <String>[];
    for (final row in table.skip(1)) {
      if (row.every((c) => c.toString().trim().isEmpty)) continue;
      final txId = _cell(row, idx, 'transaction_id');
      final key = txId.isEmpty ? 'new:${_uuid.v4()}' : txId;
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(row);
    }

    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    for (final key in order) {
      final rows = groups[key]!;
      try {
        await _importGroup(
          key: key,
          rows: rows,
          idx: idx,
          categoriesByName: categoriesByName,
          accountsByName: accountsByName,
          baseCurrency: baseCurrency,
        );
        imported++;
      } on Exception catch (e) {
        skipped++;
        errors.add('Row group "$key": $e');
      }
    }
    return ImportReport(imported: imported, skipped: skipped, errors: errors);
  }

  Future<void> _importGroup({
    required String key,
    required List<List<dynamic>> rows,
    required Map<String, int> idx,
    required Map<String, db.Category> categoriesByName,
    required Map<String, db.Account> accountsByName,
    required String baseCurrency,
  }) async {
    final head = rows.first;
    final type = enumByName(
        TxType.values, _cell(head, idx, 'type').toLowerCase(), TxType.expense);
    final date = _parseDate(_cell(head, idx, 'date'));
    final currency = _cell(head, idx, 'currency').toUpperCase();
    if (currency.isEmpty) throw const FormatException('Missing currency');
    final note = _cell(head, idx, 'note');

    final kind = type == TxType.income ? CategoryKind.income : CategoryKind.expense;
    final now = DateTime.now().toUtc();
    final txId = key.startsWith('new:') ? _uuid.v4() : key;

    final accountId = await _accountId(
        _cell(head, idx, 'account'), currency, accountsByName);
    final counterName = _cell(head, idx, 'counter_account');
    final counterId = type == TxType.transfer && counterName.isNotEmpty
        ? await _accountId(counterName, currency, accountsByName)
        : null;

    // Build line items (one per row).
    final lines = <LineItemEntity>[];
    var i = 0;
    for (final row in rows) {
      final amountStr = _firstNonEmpty(
          [_cell(row, idx, 'line_amount'), _cell(row, idx, 'total')]);
      final amount = Decimal.tryParse(amountStr.replaceAll(',', '.'));
      if (amount == null || amount <= Decimal.zero) {
        throw FormatException('Invalid amount "$amountStr"');
      }
      if (type == TxType.transfer) continue; // transfers carry no line items
      final categoryId = await _categoryId(
          _cell(row, idx, 'category'), kind, categoriesByName);
      lines.add(LineItemEntity(
        id: _uuid.v4(),
        userId: _userId,
        transactionId: txId,
        description: _firstNonEmpty(
            [_cell(row, idx, 'line_description'), note, 'Imported']),
        quantity: Decimal.one,
        lineAmount: Money(amount, currency),
        categoryId: categoryId,
        sortOrder: i++,
        updatedAt: now,
      ));
    }

    final totalDec = type == TxType.transfer
        ? (Decimal.tryParse(_cell(head, idx, 'total').replaceAll(',', '.')) ??
            (throw const FormatException('Transfer needs a total')))
        : lines.fold(Decimal.zero, (s, l) => s + l.lineAmount.amount);
    final total = Money(totalDec, currency);
    final base = await _resolveBase(total, _cell(head, idx, 'base'), date,
        baseCurrency);

    final header = TransactionEntity(
      id: txId,
      userId: _userId,
      type: type,
      date: date,
      accountId: accountId,
      counterAccountId: counterId,
      total: total,
      base: base,
      note: note.isEmpty ? null : note,
      source: TxSource.import,
      createdAt: now,
      updatedAt: now,
    );
    // Re-importing an existing transaction replaces its lines (tombstone old)
    // so a round-trip stays idempotent rather than duplicating items.
    final removed = key.startsWith('new:')
        ? const <String>[]
        : (await _db.getLineItems(txId)).map((l) => l.id).toList();
    await _tx.upsertWithLines(header, lines, removedLineItemIds: removed);
  }

  Future<Money> _resolveBase(
      Money total, String baseCell, DateTime date, String baseCurrency) async {
    if (baseCell.trim().isNotEmpty) {
      final d = Decimal.tryParse(baseCell.replaceAll(',', '.'));
      if (d != null) return Money(d, baseCurrency);
    }
    if (total.currencyCode == baseCurrency) return Money(total.amount, baseCurrency);
    final conv = await _currency.toBase(total, date);
    return conv.needsRate ? Money(total.amount, baseCurrency) : conv.base!;
  }

  Future<String> _categoryId(
      String name, CategoryKind kind, Map<String, db.Category> cache) async {
    final trimmed = name.trim().isEmpty ? 'Imported' : name.trim();
    final existing = cache[trimmed.toLowerCase()];
    if (existing != null) return existing.id;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _db.into(_db.categories).insertOnConflictUpdate(
          db.CategoriesCompanion.insert(
            id: id,
            userId: _userId,
            updatedAt: now,
            name: trimmed,
            kind: kind,
          ),
        );
    final row = (await (_db.select(_db.categories)
              ..where((c) => c.id.equals(id)))
            .getSingle());
    cache[trimmed.toLowerCase()] = row;
    return id;
  }

  Future<String> _accountId(
      String name, String currency, Map<String, db.Account> cache) async {
    final trimmed = name.trim().isEmpty ? 'Imported' : name.trim();
    final existing = cache[trimmed.toLowerCase()];
    if (existing != null) return existing.id;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _db.into(_db.accounts).insertOnConflictUpdate(
          db.AccountsCompanion.insert(
            id: id,
            userId: _userId,
            updatedAt: now,
            name: trimmed,
            kind: AccountKind.cash,
            currencyCode: currency,
            openingBalance: Decimal.zero,
          ),
        );
    final row = (await (_db.select(_db.accounts)..where((a) => a.id.equals(id)))
        .getSingle());
    cache[trimmed.toLowerCase()] = row;
    return id;
  }

  // --- small helpers -----------------------------------------------------

  String _cell(List<dynamic> row, Map<String, int> idx, String name) {
    final i = idx[name];
    if (i == null || i >= row.length) return '';
    return row[i].toString().trim();
  }

  String _firstNonEmpty(List<String> values) =>
      values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');

  DateTime _parseDate(String s) {
    final d = DateTime.tryParse(s.trim());
    if (d == null) throw FormatException('Invalid date "$s"');
    return DateTime.utc(d.year, d.month, d.day);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
