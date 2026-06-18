import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/analytics_service.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/services/drift_analytics_service.dart';
import 'package:ledgerly_app/src/data/services/drift_transaction_service.dart';
import 'package:ledgerly_app/src/domain/entities/line_item.dart';
import 'package:ledgerly_app/src/domain/entities/transaction.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/money.dart';

class _FakeAuth implements AuthService {
  @override
  AuthState get current => const AuthState(
      AuthStatus.signedIn, AuthSession(userId: 'user-1', email: 'e'));
  @override
  Stream<AuthState> watch() => Stream.value(current);
  @override
  Stream<AuthEvent> authEvents() => const Stream.empty();
  @override
  Future<void> signIn({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String email, required String password}) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  late AppDatabase db;
  final auth = _FakeAuth();
  late DriftTransactionService txService;
  late DriftAnalyticsService analytics;

  final marchRange =
      DateRange(DateTime.utc(2026, 3), DateTime.utc(2026, 4));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
    txService = DriftTransactionService(db, auth);
    analytics = DriftAnalyticsService(db, auth, 'EUR');
  });
  tearDown(() => db.close());

  TransactionEntity header({
    required String id,
    required TxType type,
    required String currency,
    required String total,
    required String base,
    required DateTime date,
  }) {
    return TransactionEntity(
      id: id,
      userId: 'user-1',
      type: type,
      date: date,
      accountId: 'acct',
      total: Money(Decimal.parse(total), currency),
      base: Money(Decimal.parse(base), currency),
      createdAt: date,
      updatedAt: date,
    );
  }

  LineItemEntity line(String id, String tx, String amount, String cat,
          String currency) =>
      LineItemEntity(
        id: id,
        userId: 'user-1',
        transactionId: tx,
        description: cat,
        quantity: Decimal.one,
        lineAmount: Money(Decimal.parse(amount), currency),
        categoryId: cat,
        updatedAt: DateTime.utc(2026),
      );

  Future<void> seedData() async {
    // EUR split expense: groceries 30 + household 20 = 50 (base = total).
    await txService.upsertWithLines(
      header(
          id: 'eur',
          type: TxType.expense,
          currency: 'EUR',
          total: '50.00',
          base: '50.00',
          date: DateTime.utc(2026, 3, 10)),
      [
        line('l1', 'eur', '30.00', 'groceries', 'EUR'),
        line('l2', 'eur', '20.00', 'household', 'EUR'),
      ],
    );
    // USD expense 10, base 9 (rate 0.9): one line in 'fuel'.
    await txService.upsertWithLines(
      header(
          id: 'usd',
          type: TxType.expense,
          currency: 'USD',
          total: '10.00',
          base: '9.00',
          date: DateTime.utc(2026, 3, 12)),
      [line('l3', 'usd', '10.00', 'fuel', 'USD')],
    );
    // EUR income (header-only).
    await txService.upsert(header(
        id: 'inc',
        type: TxType.income,
        currency: 'EUR',
        total: '100.00',
        base: '100.00',
        date: DateTime.utc(2026, 3, 15)));
  }

  test('spendByCategory attributes splits and converts foreign lines to base',
      () async {
    await seedData();
    final totals = await analytics.watchSpendByCategory(marchRange).first;
    final byId = {for (final t in totals) t.categoryId: t.total.amount};

    expect(byId['groceries'], Decimal.parse('30.00'));
    expect(byId['household'], Decimal.parse('20.00'));
    expect(byId['fuel'], Decimal.parse('9.00')); // 10 * 9 / 10
    // sorted largest-first
    expect(totals.first.categoryId, 'groceries');
    // income is not counted as spend
    expect(byId.containsKey('salary'), isFalse);
  });

  test('summary computes income, expense and net in base currency', () async {
    await seedData();
    final s = await analytics.watchSummary(marchRange).first;
    expect(s.income.amount, Decimal.parse('100.00'));
    expect(s.expense.amount, Decimal.parse('59.00')); // 50 + 9
    expect(s.net.amount, Decimal.parse('41.00'));
  });

  test('byPeriod buckets income and expense by month', () async {
    await seedData();
    final points = await analytics.watchByPeriod(Grain.month, marchRange).first;
    expect(points, hasLength(1));
    expect(points.single.periodStart, DateTime.utc(2026, 3));
    expect(points.single.inflow.amount, Decimal.parse('100.00'));
    expect(points.single.outflow.amount, Decimal.parse('59.00'));
  });

  test('drill-down returns transactions touching a category', () async {
    await seedData();
    final txs = await analytics.transactionsInCategory('groceries', marchRange);
    expect(txs.map((t) => t.id), ['eur']);
  });

  test('range filter excludes out-of-range transactions', () async {
    await seedData();
    final aprilRange = DateRange(DateTime.utc(2026, 4), DateTime.utc(2026, 5));
    final totals = await analytics.watchSpendByCategory(aprilRange).first;
    expect(totals, isEmpty);
  });
}
