import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/seed/database_seeder.dart';
import 'package:ledgerly_app/src/data/services/drift_currency_service.dart';
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

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
  });
  tearDown(() => db.close());

  TransactionEntity header(String id) {
    final now = DateTime.utc(2026, 6, 18);
    final money = Money(Decimal.parse('324.00'), 'CZK');
    return TransactionEntity(
      id: id,
      userId: 'user-1',
      type: TxType.expense,
      date: now,
      accountId: 'acct',
      total: money,
      base: money,
      createdAt: now,
      updatedAt: now,
    );
  }

  LineItemEntity line(String id, String amount, String category) =>
      LineItemEntity(
        id: id,
        userId: 'user-1',
        transactionId: 'tx-1',
        description: category,
        quantity: Decimal.one,
        lineAmount: Money(Decimal.parse(amount), 'CZK'),
        categoryId: category,
        updatedAt: DateTime.utc(2026),
      );

  group('transactions with line items', () {
    test(
      'upsertWithLines persists lines read back in the tx currency',
      () async {
        final service = DriftTransactionService(db, auth);
        await service.upsertWithLines(header('tx-1'), [
          line('l1', '149.40', 'alcohol'),
          line('l2', '174.60', 'groceries'),
        ]);

        final lines = await service.watchLineItems('tx-1').first;
        expect(lines, hasLength(2));
        expect(
          lines.map((l) => l.lineAmount.currencyCode),
          everyElement('CZK'),
        );
        expect(
          lines.fold(Decimal.zero, (s, l) => s + l.lineAmount.amount),
          Decimal.parse('324.00'),
        );
      },
    );

    test('softDelete tombstones the header and its line items', () async {
      final service = DriftTransactionService(db, auth);
      await service.upsertWithLines(header('tx-1'), [
        line('l1', '324.00', 'a'),
      ]);
      await service.softDelete('tx-1');

      expect(await service.watchAll().first, isEmpty);
      expect(await service.watchLineItems('tx-1').first, isEmpty);
      final rawLines = await db.select(db.lineItems).get();
      expect(rawLines.single.deleted, isTrue); // tombstone, not hard delete
    });
  });

  group('seeding + currency conversion', () {
    test(
      'seed installs categories, currencies, and the base currency',
      () async {
        await DatabaseSeeder(db).seed(userId: 'user-1', baseCurrency: 'EUR');

        expect(await db.countCategories('user-1'), greaterThan(0));
        final currencies = await db.watchCurrencies().first;
        expect(currencies.map((c) => c.id), contains('EUR'));

        final currency = DriftCurrencyService(db, auth, 'USD');
        expect(await currency.baseCurrencyCode(), 'EUR');
      },
    );

    test(
      'toBase converts using the most recent rate on/before the date',
      () async {
        await DatabaseSeeder(db).seed(userId: 'user-1', baseCurrency: 'EUR');
        await db.into(db.exchangeRates).insert(
              ExchangeRatesCompanion.insert(
                id: 'fx1',
                userId: 'user-1',
                updatedAt: DateTime.utc(2026),
                fromCode: 'USD',
                toCode: 'EUR',
                rate: Decimal.parse('0.90'),
                date: DateTime.utc(2026, 6, 1),
                source: RateSource.manual,
              ),
            );

        final currency = DriftCurrencyService(db, auth, 'EUR');
        final result = await currency.toBase(
          Money(Decimal.parse('10.00'), 'USD'),
          DateTime.utc(2026, 6, 18),
        );

        expect(result.needsRate, isFalse);
        expect(result.base!.currencyCode, 'EUR');
        expect(result.base!.amount, Decimal.parse('9.00'));
      },
    );

    test('toBase reports rateMissing when no rate exists', () async {
      await DatabaseSeeder(db).seed(userId: 'user-1', baseCurrency: 'EUR');
      final currency = DriftCurrencyService(db, auth, 'EUR');
      final result = await currency.toBase(
        Money(Decimal.parse('10.00'), 'USD'),
        DateTime.utc(2026, 6, 18),
      );
      expect(result.needsRate, isTrue);
    });
  });
}
