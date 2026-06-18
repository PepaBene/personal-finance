import 'package:drift/drift.dart';

import '../../application/account_service.dart';
import '../../application/auth_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/enums.dart';
import '../../domain/money.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [AccountService]. Balances are folded in Dart with [Decimal]
/// (money is TEXT, so SQL SUM is unsafe — docs/04 §3.4).
///
/// Note (MVP): balances aggregate only transactions in the account's own
/// currency; cross-currency postings are excluded until per-account base
/// conversion lands. Recomputes on transaction changes.
class DriftAccountService implements AccountService {
  DriftAccountService(this._db, this._auth);

  final db.AppDatabase _db;
  final AuthService _auth;

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  @override
  Stream<List<AccountEntity>> watchAll() {
    return _db
        .watchAccounts(_userId)
        .map((rows) => rows.map(_toEntity).toList(growable: false));
  }

  @override
  Stream<List<AccountBalance>> watchBalances() {
    // React to transaction changes (the frequent input); re-read accounts each
    // emission so newly added accounts also appear.
    return _db.watchActive(_userId).asyncMap((txs) async {
      final accounts =
          await (_db.select(_db.accounts)..where(
                (a) => a.userId.equals(_userId) & a.deleted.equals(false),
              ))
              .get();
      return accounts.map((a) => _balanceFor(a, txs)).toList(growable: false);
    });
  }

  @override
  Future<AccountEntity> upsert(AccountEntity account) async {
    final next = account.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version: account.version + 1,
    );
    await _db.into(_db.accounts).insertOnConflictUpdate(_toCompanion(next));
    return next;
  }

  @override
  Future<void> archive(String id) async {
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      db.AccountsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  AccountBalance _balanceFor(db.Account a, List<db.Transaction> txs) {
    var balance = Money(a.openingBalance, a.currencyCode);
    for (final t in txs) {
      if (t.currencyCode != a.currencyCode) continue; // see class note
      final amount = Money(t.totalAmount, a.currencyCode);
      if (t.accountId == a.id) {
        switch (t.type) {
          case TxType.income:
            balance += amount;
          case TxType.expense:
          case TxType.transfer: // leaves the source account
            balance -= amount;
        }
      }
      if (t.type == TxType.transfer && t.counterAccountId == a.id) {
        balance += amount; // arrives at the destination account
      }
    }
    return AccountBalance(_toEntity(a), balance);
  }

  AccountEntity _toEntity(db.Account r) => AccountEntity(
    id: r.id,
    userId: r.userId,
    name: r.name,
    kind: r.kind,
    currencyCode: r.currencyCode,
    openingBalance: Money(r.openingBalance, r.currencyCode),
    isArchived: r.isArchived,
    updatedAt: r.updatedAt,
    deleted: r.deleted,
    version: r.version,
  );

  db.AccountsCompanion _toCompanion(AccountEntity e) =>
      db.AccountsCompanion.insert(
        id: e.id,
        userId: e.userId,
        updatedAt: e.updatedAt,
        name: e.name,
        kind: e.kind,
        currencyCode: e.currencyCode,
        openingBalance: e.openingBalance.amount,
        isArchived: Value(e.isArchived),
        deleted: Value(e.deleted),
        version: Value(e.version),
      );
}
