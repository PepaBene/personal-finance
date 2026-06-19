import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/analytics_service.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/services/drift_analytics_service.dart';
import 'package:ledgerly_app/src/data/services/drift_budget_service.dart';
import 'package:ledgerly_app/src/data/services/drift_transaction_service.dart';
import 'package:ledgerly_app/src/domain/entities/budget.dart';
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
  late DriftBudgetService budgetService;
  late DriftAnalyticsService analytics;

  final marchRange = DateRange(DateTime.utc(2026, 3), DateTime.utc(2026, 4));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
    txService = DriftTransactionService(db, auth);
    budgetService = DriftBudgetService(db, auth);
    analytics = DriftAnalyticsService(db, auth, 'EUR');
  });
  tearDown(() => db.close());

  TransactionEntity header({
    required String id,
    required String currency,
    required String total,
    required String base,
    required DateTime date,
  }) {
    return TransactionEntity(
      id: id,
      userId: 'user-1',
      type: TxType.expense,
      date: date,
      accountId: 'acct',
      total: Money(Decimal.parse(total), currency),
      base: Money(Decimal.parse(base), currency),
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

  BudgetEntity budget(String id, String cat, String limit) => BudgetEntity(
        id: id,
        userId: 'user-1',
        categoryId: cat,
        amount: Money(Decimal.parse(limit), 'EUR'),
        startMonth: DateTime.utc(2026, 1),
        updatedAt: DateTime.utc(2026),
      );

  Future<void> seedSpend() async {
    // EUR split expense: groceries 30 + household 20 = 50 (base = total).
    await txService.upsertWithLines(
      header(
        id: 'eur',
        currency: 'EUR',
        total: '50.00',
        base: '50.00',
        date: DateTime.utc(2026, 3, 10),
      ),
      [
        line('l1', 'eur', '30.00', 'groceries'),
        line('l2', 'eur', '20.00', 'household'),
      ],
    );
    // USD expense 10, base 9 (rate 0.9): one line in 'fuel'.
    await txService.upsertWithLines(
      header(
        id: 'usd',
        currency: 'USD',
        total: '10.00',
        base: '9.00',
        date: DateTime.utc(2026, 3, 12),
      ),
      [
        LineItemEntity(
          id: 'l3',
          userId: 'user-1',
          transactionId: 'usd',
          description: 'fuel',
          quantity: Decimal.one,
          lineAmount: Money(Decimal.parse('10.00'), 'USD'),
          categoryId: 'fuel',
          updatedAt: DateTime.utc(2026),
        ),
      ],
    );
  }

  test('budget service round-trips and tombstones on delete', () async {
    final saved = await budgetService.upsert(budget('b1', 'groceries', '50.00'));
    expect(saved.version, 1);
    var all = await budgetService.getAll();
    expect(all.map((b) => b.id), ['b1']);

    await budgetService.delete('b1');
    all = await budgetService.getAll();
    expect(all, isEmpty);
  });

  test('budget status computes actual, utilization and alert level', () async {
    await seedSpend();
    await budgetService.upsert(budget('b1', 'groceries', '50.00')); // 30/50
    await budgetService.upsert(budget('b2', 'household', '20.00')); // 20/20
    await budgetService.upsert(budget('b3', 'fuel', '10.00')); //  9/10
    await budgetService.upsert(budget('b4', 'dining', '40.00')); //  0/40

    final statuses = await analytics.watchBudgetStatus(marchRange).first;
    final byCat = {for (final s in statuses) s.budget.categoryId: s};

    expect(byCat['groceries']!.actual.amount, Decimal.parse('30.00'));
    expect(byCat['groceries']!.level, BudgetAlertLevel.ok);

    expect(byCat['household']!.actual.amount, Decimal.parse('20.00'));
    expect(byCat['household']!.level, BudgetAlertLevel.over);

    expect(byCat['fuel']!.actual.amount, Decimal.parse('9.00'));
    expect(byCat['fuel']!.level, BudgetAlertLevel.nearing);
    expect(byCat['fuel']!.remaining.amount, Decimal.parse('1.00'));

    expect(byCat['dining']!.actual.amount, Decimal.parse('0.00'));
    expect(byCat['dining']!.level, BudgetAlertLevel.ok);

    // Most-stretched first.
    expect(statuses.first.budget.categoryId, 'household');
  });

  test('inactive or future-dated budgets are excluded', () async {
    await seedSpend();
    await budgetService.upsert(
      budget('b1', 'groceries', '50.00').copyWith(isActive: false),
    );
    await budgetService.upsert(
      budget('b2', 'household', '20.00')
          .copyWith(startMonth: DateTime.utc(2026, 6)),
    );
    final statuses = await analytics.watchBudgetStatus(marchRange).first;
    expect(statuses, isEmpty);
  });
}
