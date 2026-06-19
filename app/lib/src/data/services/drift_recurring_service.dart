import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../application/auth_service.dart';
import '../../application/currency_service.dart';
import '../../application/recurring_service.dart';
import '../../application/transaction_service.dart';
import '../../domain/entities/line_item.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [RecurringService]. Templates live in the local encrypted DB and
/// sync underneath; generation writes real transactions through the
/// [TransactionService] so they pick up the same persistence + sync path as
/// manual entries (source = recurring).
class DriftRecurringService implements RecurringService {
  DriftRecurringService(this._db, this._auth, this._tx, this._currency);

  final db.AppDatabase _db;
  final AuthService _auth;
  final TransactionService _tx;
  final CurrencyService _currency;
  final _uuid = const Uuid();

  /// Safety cap so a misconfigured far-past template can't generate forever.
  static const _maxOccurrencesPerRun = 120;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  @override
  Stream<List<RecurringTemplateEntity>> watchAll() {
    return _db
        .watchRecurringTemplates(_userId)
        .map((rows) => rows.map(_toEntity).toList(growable: false));
  }

  @override
  Future<RecurringTemplateEntity> upsert(
    RecurringTemplateEntity template,
  ) async {
    final next = template.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version: template.version + 1,
    );
    await _db.upsertRecurringTemplate(_toCompanion(next));
    return next;
  }

  @override
  Future<void> delete(String id) =>
      _db.softDeleteRecurringTemplate(id, DateTime.now().toUtc());

  @override
  Future<int> generateDue(DateTime asOf) async {
    final asOfUtc = asOf.toUtc();
    final rows = await _db.getRecurringTemplates(_userId);
    var created = 0;
    for (final row in rows) {
      var template = _toEntity(row);
      if (!template.isActive) continue;
      var guard = 0;
      while (!template.nextDate.isAfter(asOfUtc) &&
          guard < _maxOccurrencesPerRun) {
        await _createOccurrence(template, template.nextDate);
        created++;
        guard++;
        template = template.copyWith(
          lastRunDate: template.nextDate,
          nextDate: template.advance(template.nextDate),
        );
      }
      // Persist the advanced schedule (only if it moved).
      if (guard > 0) await upsert(template);
    }
    return created;
  }

  Future<void> _createOccurrence(
    RecurringTemplateEntity t,
    DateTime date,
  ) async {
    final day = DateTime.utc(date.year, date.month, date.day);
    final total = t.amount;
    final base = await _resolveBase(total, day);
    final now = DateTime.now().toUtc();
    final header = TransactionEntity(
      id: _uuid.v4(),
      userId: t.userId,
      type: t.type,
      date: day,
      accountId: t.accountId,
      merchantId: t.merchantId,
      total: total,
      base: base,
      note: t.note,
      source: TxSource.recurring,
      createdAt: now,
      updatedAt: now,
    );
    final line = LineItemEntity(
      id: _uuid.v4(),
      userId: t.userId,
      transactionId: header.id,
      description: t.name,
      quantity: Decimal.one,
      lineAmount: total,
      categoryId: t.categoryId,
      updatedAt: now,
    );
    await _tx.upsertWithLines(header, [line]);
  }

  /// Convert to base currency for the occurrence's date. Generation runs
  /// unattended, so when no rate exists for a foreign currency we fall back to
  /// the original amount rather than failing the whole run (the user can fix the
  /// rate later; same-currency templates — the common case — are exact).
  Future<Money> _resolveBase(Money total, DateTime date) async {
    final result = await _currency.toBase(total, date);
    return result.base ?? total;
  }

  RecurringTemplateEntity _toEntity(db.RecurringTemplate r) =>
      RecurringTemplateEntity(
        id: r.id,
        userId: r.userId,
        type: r.type,
        name: r.name,
        accountId: r.accountId,
        categoryId: r.categoryId,
        amount: Money(r.amount, r.currencyCode),
        frequency: r.frequency,
        nextDate: r.nextDate,
        merchantId: r.merchantId,
        note: r.note,
        lastRunDate: r.lastRunDate,
        isActive: r.isActive,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );

  db.RecurringTemplatesCompanion _toCompanion(RecurringTemplateEntity e) =>
      db.RecurringTemplatesCompanion.insert(
        id: e.id,
        userId: e.userId,
        updatedAt: e.updatedAt,
        type: e.type,
        name: e.name,
        accountId: e.accountId,
        categoryId: e.categoryId,
        currencyCode: e.amount.currencyCode,
        amount: e.amount.amount,
        frequency: e.frequency,
        nextDate: e.nextDate,
        merchantId: Value(e.merchantId),
        note: Value(e.note),
        lastRunDate: Value(e.lastRunDate),
        isActive: Value(e.isActive),
        deleted: Value(e.deleted),
        version: Value(e.version),
      );
}
