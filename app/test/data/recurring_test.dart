import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/services/drift_currency_service.dart';
import 'package:ledgerly_app/src/data/services/drift_recurring_service.dart';
import 'package:ledgerly_app/src/data/services/drift_transaction_service.dart';
import 'package:ledgerly_app/src/domain/entities/recurring_template.dart';
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
  late DriftRecurringService recurring;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
    txService = DriftTransactionService(db, auth);
    final currency = DriftCurrencyService(db, auth, 'EUR');
    recurring = DriftRecurringService(db, auth, txService, currency);
  });
  tearDown(() => db.close());

  RecurringTemplateEntity template() => RecurringTemplateEntity(
        id: 't1',
        userId: 'user-1',
        type: TxType.expense,
        name: 'Netflix',
        accountId: 'acct',
        categoryId: 'subscriptions',
        amount: Money(Decimal.parse('9.99'), 'EUR'),
        frequency: RecurringFrequency.monthly,
        nextDate: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026),
      );

  test('generateDue creates one transaction per due occurrence', () async {
    await recurring.upsert(template());

    final created = await recurring.generateDue(DateTime.utc(2026, 3, 15));
    expect(created, 3); // Jan 1, Feb 1, Mar 1

    final txs = await txService.watchAll().first;
    expect(txs, hasLength(3));
    expect(txs.every((t) => t.source == TxSource.recurring), isTrue);
    expect(
      txs.map((t) => t.date).toSet(),
      {
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 2, 1),
        DateTime.utc(2026, 3, 1),
      },
    );

    // The template advanced past the generated window.
    final tpl = (await recurring.watchAll().first).single;
    expect(tpl.nextDate, DateTime.utc(2026, 4, 1));
    expect(tpl.lastRunDate, DateTime.utc(2026, 3, 1));
  });

  test('generateDue is idempotent on re-run', () async {
    await recurring.upsert(template());
    await recurring.generateDue(DateTime.utc(2026, 3, 15));

    final again = await recurring.generateDue(DateTime.utc(2026, 3, 15));
    expect(again, 0);
    expect(await txService.watchAll().first, hasLength(3));

    // A later as-of generates only the newly-due occurrence.
    final more = await recurring.generateDue(DateTime.utc(2026, 4, 2));
    expect(more, 1);
    expect(await txService.watchAll().first, hasLength(4));
  });

  test('inactive templates generate nothing', () async {
    await recurring.upsert(template().copyWith(isActive: false));
    final created = await recurring.generateDue(DateTime.utc(2026, 12, 31));
    expect(created, 0);
  });

  test('delete tombstones the template', () async {
    await recurring.upsert(template());
    await recurring.delete('t1');
    expect(await recurring.watchAll().first, isEmpty);
  });
}
