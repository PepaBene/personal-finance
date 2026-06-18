import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/services/drift_transaction_service.dart';
import 'package:ledgerly_app/src/domain/entities/transaction.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/domain/money.dart';

/// Fake auth so the service has a stable signed-in user without Supabase.
class _FakeAuth implements AuthService {
  _FakeAuth(this.userId);
  final String userId;

  @override
  AuthState get current => AuthState(
        AuthStatus.signedIn,
        AuthSession(userId: userId, email: 'test@example.com'),
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
  late DriftTransactionService service;

  TransactionEntity sample(String id) {
    final now = DateTime.utc(2026, 6, 18, 12);
    final money = Money(Decimal.parse('12.34'), 'EUR');
    return TransactionEntity(
      id: id,
      userId: 'user-1',
      type: TxType.expense,
      date: now,
      accountId: 'default',
      total: money,
      base: money,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // In production PowerSync creates the synced tables; the Drift migration is
    // a no-op. For an isolated in-memory test we materialize the schema here.
    await db.createMigrator().createAll();
    service = DriftTransactionService(db, _FakeAuth('user-1'));
  });

  tearDown(() => db.close());

  test('upsert stamps updatedAt and bumps version', () async {
    final saved = await service.upsert(sample('tx-1'));
    expect(saved.version, 1);
    expect(saved.deleted, isFalse);
  });

  test('watchAll streams the persisted transaction', () async {
    await service.upsert(sample('tx-1'));
    final list = await service.watchAll().first;
    expect(list, hasLength(1));
    expect(list.single.id, 'tx-1');
    expect(list.single.total.amount, Decimal.parse('12.34'));
  });

  test(
    'softDelete tombstones the row so it leaves the active stream',
    () async {
      await service.upsert(sample('tx-1'));
      await service.softDelete('tx-1');
      final list = await service.watchAll().first;
      expect(list, isEmpty);

      // The row still exists physically (tombstone), so deletion can propagate.
      final raw = await db.select(db.transactions).get();
      expect(raw.single.deleted, isTrue);
      expect(raw.single.status, TxStatus.deleted);
    },
  );
}
