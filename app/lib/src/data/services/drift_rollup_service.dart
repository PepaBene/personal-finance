import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:rational/rational.dart';

import '../../application/auth_service.dart';
import '../../application/rollup_service.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [RollupService]. Recomputes the local-only monthly rollup cache
/// from expense line items using the same per-line base attribution as the
/// analytics service (splits + multi-currency correct, docs/11 §1.2).
class DriftRollupService implements RollupService {
  DriftRollupService(this._db, this._auth, this._defaultBaseCurrency);

  final db.AppDatabase _db;
  final AuthService _auth;
  final String _defaultBaseCurrency;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  Future<String> _baseCurrency() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.id.equals('$_userId::base_currency')))
        .getSingleOrNull();
    return row?.value ?? _defaultBaseCurrency;
  }

  @override
  Future<int> rebuild() async {
    final userId = _userId;

    final rows = await (_db.select(_db.lineItems).join([
      innerJoin(
        _db.transactions,
        _db.transactions.id.equalsExp(_db.lineItems.transactionId),
      ),
    ])
          ..where(
            _db.lineItems.deleted.equals(false) &
                _db.transactions.deleted.equals(false) &
                _db.transactions.status.equalsValue(TxStatus.active) &
                _db.transactions.type.equalsValue(TxType.expense),
          ))
        .get();

    // (month, categoryId) → exact base-currency share.
    final acc = <DateTime, Map<String, Rational>>{};
    for (final row in rows) {
      final line = row.readTable(_db.lineItems);
      final tx = row.readTable(_db.transactions);
      if (tx.totalAmount == Decimal.zero) continue;
      final d = tx.date.toUtc();
      final month = DateTime.utc(d.year, d.month);
      final share = (line.lineAmount * tx.baseAmount) / tx.totalAmount;
      final byCat = acc.putIfAbsent(month, () => <String, Rational>{});
      byCat[line.categoryId] = (byCat[line.categoryId] ?? Rational.zero) + share;
    }

    final companions = <db.MonthlyRollupsCompanion>[];
    acc.forEach((month, byCat) {
      byCat.forEach((categoryId, share) {
        companions.add(
          db.MonthlyRollupsCompanion.insert(
            id: '$userId|${month.toIso8601String()}|$categoryId',
            userId: userId,
            periodMonth: month,
            categoryId: categoryId,
            baseAmount: share.toDecimal(scaleOnInfinitePrecision: 2),
          ),
        );
      });
    });

    await _db.replaceMonthlyRollups(userId, companions);
    return companions.length;
  }

  @override
  Future<List<MonthlyCategoryRollup>> categoryRollups() async {
    final base = await _baseCurrency();
    final rows = await _db.getMonthlyRollups(_userId);
    return [
      for (final r in rows)
        MonthlyCategoryRollup(
          month: r.periodMonth,
          categoryId: r.categoryId,
          amount: Money(r.baseAmount, base),
        ),
    ];
  }

  @override
  Future<List<MonthlyTotal>> monthlyTotals() async {
    final base = await _baseCurrency();
    final rows = await _db.getMonthlyRollups(_userId);
    final byMonth = <DateTime, Decimal>{};
    for (final r in rows) {
      byMonth[r.periodMonth] = (byMonth[r.periodMonth] ?? Decimal.zero) +
          r.baseAmount;
    }
    final months = byMonth.keys.toList()..sort();
    return [
      for (final m in months)
        MonthlyTotal(month: m, amount: Money(byMonth[m]!, base)),
    ];
  }
}
