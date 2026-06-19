import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
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
  late DriftAnalyticsService analytics;

  final march = DateRange(DateTime.utc(2026, 3), DateTime.utc(2026, 4));
  final february = DateRange(DateTime.utc(2026, 2), DateTime.utc(2026, 3));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
    txService = DriftTransactionService(db, auth);
    analytics = DriftAnalyticsService(db, auth, 'EUR');
  });
  tearDown(() => db.close());

  Future<void> merchant(String id, String name) {
    return db.into(db.merchants).insert(
          MerchantsCompanion.insert(
            id: id,
            userId: 'user-1',
            updatedAt: DateTime.utc(2026),
            name: name,
          ),
        );
  }

  TransactionEntity header({
    required String id,
    required TxType type,
    required String base,
    required DateTime date,
    String? merchantId,
  }) {
    return TransactionEntity(
      id: id,
      userId: 'user-1',
      type: type,
      date: date,
      accountId: 'acct',
      merchantId: merchantId,
      total: Money(Decimal.parse(base), 'EUR'),
      base: Money(Decimal.parse(base), 'EUR'),
      createdAt: date,
      updatedAt: date,
    );
  }

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
    await merchant('m1', 'Albert');
    await merchant('m2', 'Lidl');
    await txService.upsertWithLines(
      header(
        id: 'm1a',
        type: TxType.expense,
        base: '50.00',
        date: DateTime.utc(2026, 3, 5),
        merchantId: 'm1',
      ),
      [line('l1', 'm1a', '50.00', 'groceries')],
    );
    await txService.upsertWithLines(
      header(
        id: 'm1b',
        type: TxType.expense,
        base: '20.00',
        date: DateTime.utc(2026, 3, 6),
        merchantId: 'm1',
      ),
      [line('l2', 'm1b', '20.00', 'dining')],
    );
    await txService.upsertWithLines(
      header(
        id: 'm2c',
        type: TxType.expense,
        base: '30.00',
        date: DateTime.utc(2026, 3, 7),
        merchantId: 'm2',
      ),
      [line('l3', 'm2c', '30.00', 'groceries')],
    );
    await txService.upsert(
      header(
        id: 'inc',
        type: TxType.income,
        base: '100.00',
        date: DateTime.utc(2026, 3, 8),
      ),
    );
    // February prior period for comparison.
    await txService.upsertWithLines(
      header(
        id: 'f1',
        type: TxType.expense,
        base: '40.00',
        date: DateTime.utc(2026, 2, 5),
        merchantId: 'm1',
      ),
      [line('l4', 'f1', '40.00', 'groceries')],
    );
  }

  test('top merchants rank by base expense and resolve names', () async {
    await seed();
    final tops = await analytics.watchTopMerchants(march).first;
    expect(tops.map((m) => m.merchantId), ['m1', 'm2']);
    expect(tops.first.name, 'Albert');
    expect(tops.first.total.amount, Decimal.parse('70.00')); // 50 + 20
    expect(tops[1].total.amount, Decimal.parse('30.00'));
  });

  test('top merchants honours the limit', () async {
    await seed();
    final tops = await analytics.watchTopMerchants(march, limit: 1).first;
    expect(tops, hasLength(1));
    expect(tops.single.merchantId, 'm1');
  });

  test('daily spend buckets expense per day, income excluded', () async {
    await seed();
    final days = await analytics.watchDailySpend(march).first;
    expect(days.map((d) => d.day), [
      DateTime.utc(2026, 3, 5),
      DateTime.utc(2026, 3, 6),
      DateTime.utc(2026, 3, 7),
    ]);
    expect(days.first.amount.amount, Decimal.parse('50.00'));
  });

  test('category comparison computes current vs previous and change', () async {
    await seed();
    final cmp = await analytics.categoryComparison(march, february);
    final byCat = {for (final c in cmp) c.categoryId: c};
    expect(byCat['groceries']!.current.amount, Decimal.parse('80.00'));
    expect(byCat['groceries']!.previous.amount, Decimal.parse('40.00'));
    expect(byCat['groceries']!.change, closeTo(1.0, 1e-9)); // +100%
    expect(byCat['dining']!.previous.amount, Decimal.zero);
    expect(byCat['dining']!.change, isNull); // no prior spend
    // Biggest absolute move first.
    expect(cmp.first.categoryId, 'groceries');
  });

  test('cashflow waterfall: income, top categories, net', () async {
    await seed();
    final steps = await analytics.cashflowWaterfall(march);
    expect(steps.first.key, 'income');
    expect(steps.first.delta.amount, Decimal.parse('100.00'));
    expect(steps.last.key, 'net');
    expect(steps.last.isTotal, isTrue);
    expect(steps.last.delta.amount, Decimal.zero); // 100 income - 100 expense
    // Expense steps are negative.
    final groceries = steps.firstWhere((s) => s.key == 'groceries');
    expect(groceries.delta.amount, Decimal.parse('-80.00'));
  });
}
