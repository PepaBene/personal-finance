import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/seed/database_seeder.dart';
import 'package:ledgerly_app/src/data/services/drift_currency_service.dart';
import 'package:ledgerly_app/src/data/services/drift_import_export_service.dart';
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

DriftImportExportService _ie(AppDatabase db, AuthService auth) =>
    DriftImportExportService(
      db,
      auth,
      DriftTransactionService(db, auth),
      DriftCurrencyService(db, auth, 'EUR'),
    );

void main() {
  final auth = _FakeAuth();

  test('export then import into a fresh DB reconstructs the split', () async {
    final src = AppDatabase(NativeDatabase.memory());
    await src.createMigrator().createAll();
    addTearDown(src.close);
    await DatabaseSeeder(src).seed(userId: 'user-1', baseCurrency: 'EUR');

    final cats = await src.watchCategories('user-1').first;
    final groceries = cats.firstWhere((c) => c.name == 'Groceries').id;
    final dining = cats.firstWhere((c) => c.name == 'Dining').id;

    final now = DateTime.utc(2026, 3, 10);
    final money = Money(Decimal.parse('50.00'), 'EUR');
    await DriftTransactionService(src, auth).upsertWithLines(
      TransactionEntity(
        id: 'tx-1',
        userId: 'user-1',
        type: TxType.expense,
        date: now,
        accountId: 'acct',
        total: money,
        base: money,
        createdAt: now,
        updatedAt: now,
      ),
      [
        LineItemEntity(
          id: 'l1',
          userId: 'user-1',
          transactionId: 'tx-1',
          description: 'Veg',
          quantity: Decimal.one,
          lineAmount: Money(Decimal.parse('30.00'), 'EUR'),
          categoryId: groceries,
          updatedAt: now,
        ),
        LineItemEntity(
          id: 'l2',
          userId: 'user-1',
          transactionId: 'tx-1',
          description: 'Lunch',
          quantity: Decimal.one,
          lineAmount: Money(Decimal.parse('20.00'), 'EUR'),
          categoryId: dining,
          updatedAt: now,
        ),
      ],
    );

    final csv = await _ie(src, auth).exportCsv();
    expect(csv, contains('Groceries'));
    expect(csv, contains('transaction_id'));

    // Import into a fresh DB with no categories/accounts.
    final dst = AppDatabase(NativeDatabase.memory());
    await dst.createMigrator().createAll();
    addTearDown(dst.close);

    final report = await _ie(dst, auth).importCsv(csv);
    expect(report.imported, 1);
    expect(report.skipped, 0);

    final txs = await dst.select(dst.transactions).get();
    expect(txs.single.id, 'tx-1');
    expect(txs.single.totalAmount, Decimal.parse('50.00'));

    final lines = await dst.getLineItems('tx-1');
    expect(lines, hasLength(2));
    expect(lines.map((l) => l.lineAmount).toSet(), {
      Decimal.parse('30.00'),
      Decimal.parse('20.00'),
    });

    // Categories were re-created by name.
    final dstCats = await dst.watchCategories('user-1').first;
    expect(dstCats.map((c) => c.name), containsAll(['Groceries', 'Dining']));
  });

  test('re-importing the same CSV is idempotent (no duplicate lines)',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
    addTearDown(db.close);
    await DatabaseSeeder(db).seed(userId: 'user-1', baseCurrency: 'EUR');

    const csv = 'transaction_id,date,type,account,counter_account,currency,'
        'total,base,note,line_description,line_amount,category\r\n'
        'tx-9,2026-03-10,expense,Cash,,EUR,40.00,40.00,,Stuff,40.00,Groceries';

    await _ie(db, auth).importCsv(csv);
    await _ie(db, auth).importCsv(csv);

    final lines = await db.getLineItems('tx-9');
    expect(lines, hasLength(1));
    expect(lines.single.lineAmount, Decimal.parse('40.00'));
  });
}
