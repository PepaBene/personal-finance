import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/services/drift_rollup_service.dart';
import 'package:ledgerly_app/src/data/services/drift_transaction_service.dart';
import 'package:ledgerly_app/src/domain/entities/line_item.dart';
import 'package:ledgerly_app/src/domain/entities/transaction.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/money.dart';

class _FakeAuth implements AuthService {
  @override
  AuthState get current => const AuthState(
        AuthStatus.signedIn,
        AuthSession(userId: 'user-1', email: 'e'),
      );
  @override
  Stream<AuthState> watch() => Stream.value(current);
  @override
  Stream<AuthEvent> authEvents() => const Stream.empty();
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  late AppDatabase db;
  final auth = _FakeAuth();
  late DriftTransactionService txService;
  late DriftRollupService rollups;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
    txService = DriftTransactionService(db, auth);
    rollups = DriftRollupService(db, auth, 'EUR');
  });
  tearDown(() => db.close());

  TransactionEntity header(String id, String base, DateTime date) =>
      TransactionEntity(
        id: id,
        userId: 'user-1',
        type: TxType.expense,
        date: date,
        accountId: 'a',
        total: Money(Decimal.parse(base), 'EUR'),
        base: Money(Decimal.parse(base), 'EUR'),
        createdAt: date,
        updatedAt: date,
      );

  LineItemEntity line(String id, String tx, String amount, String cat) =>
      LineItemEntity(
        id: id,
        userId: 'user-1',
        transactionId: tx,
        description: cat,
        quantity: Decimal.one,
        lineAmount: Money(Decimal.parse(amount), 'EUR'),
        categoryId: cat,
        updatedAt: DateTime.utc(2026),
      );

  Future<void> seed() async {
    await txService.upsertWithLines(
      header('m1', '50.00', DateTime.utc(2026, 1, 10)),
      [line('a', 'm1', '30.00', 'groceries'), line('b', 'm1', '20.00', 'fun')],
    );
    await txService.upsertWithLines(
      header('m2', '40.00', DateTime.utc(2026, 1, 20)),
      [line('c', 'm2', '40.00', 'groceries')],
    );
    await txService.upsertWithLines(
      header('m3', '15.00', DateTime.utc(2026, 2, 5)),
      [line('d', 'm3', '15.00', 'groceries')],
    );
  }

  test('rebuild aggregates spend per month and category', () async {
    await seed();
    final count = await rollups.rebuild();
    // Jan: groceries, fun; Feb: groceries → 3 rows.
    expect(count, 3);

    final byKey = {
      for (final r in await rollups.categoryRollups())
        '${r.month.toIso8601String()}|${r.categoryId}': r.amount.amount,
    };
    expect(byKey['2026-01-01T00:00:00.000Z|groceries'],
        Decimal.parse('70.00')); // 30 + 40
    expect(byKey['2026-01-01T00:00:00.000Z|fun'], Decimal.parse('20.00'));
    expect(byKey['2026-02-01T00:00:00.000Z|groceries'],
        Decimal.parse('15.00'));
  });

  test('monthlyTotals rolls categories up per month', () async {
    await seed();
    await rollups.rebuild();
    final totals = await rollups.monthlyTotals();
    expect(totals.map((t) => t.month), [
      DateTime.utc(2026, 1),
      DateTime.utc(2026, 2),
    ]);
    expect(totals.first.amount.amount, Decimal.parse('90.00')); // 70 + 20
    expect(totals.last.amount.amount, Decimal.parse('15.00'));
  });

  test('rebuild is idempotent (no duplicate rows)', () async {
    await seed();
    final first = await rollups.rebuild();
    final second = await rollups.rebuild();
    expect(second, first);
    expect(await rollups.categoryRollups(), hasLength(first));
  });
}
