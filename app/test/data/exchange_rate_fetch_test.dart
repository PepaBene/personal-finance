import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/application/exchange_rate_provider.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/remote/frankfurter_rate_provider.dart';
import 'package:ledgerly_app/src/data/services/drift_currency_service.dart';
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

/// Returns a fixed rate without touching the network.
class _FakeRateProvider implements ExchangeRateProvider {
  _FakeRateProvider(this.rate);
  final Decimal rate;
  int calls = 0;

  @override
  Future<FetchedRate> fetch({
    required String from,
    required String to,
    required DateTime date,
  }) async {
    calls++;
    return FetchedRate(rate: rate, date: date);
  }
}

void main() {
  group('FrankfurterRateProvider.parseResponse', () {
    test('extracts the requested currency rate and date', () {
      const body =
          '{"amount":1.0,"base":"USD","date":"2026-01-02","rates":{"EUR":0.95}}';
      final result = FrankfurterRateProvider.parseResponse(body, 'EUR');
      expect(result.rate, Decimal.parse('0.95'));
      expect(result.date, DateTime.utc(2026, 1, 2));
    });

    test('throws when the currency is absent', () {
      const body = '{"base":"USD","date":"2026-01-02","rates":{"GBP":0.8}}';
      expect(
        () => FrankfurterRateProvider.parseResponse(body, 'EUR'),
        throwsA(isA<RateFetchException>()),
      );
    });

    test('throws on malformed JSON', () {
      expect(
        () => FrankfurterRateProvider.parseResponse('not json', 'EUR'),
        throwsA(isA<RateFetchException>()),
      );
    });
  });

  group('DriftCurrencyService.fetchOnlineRate', () {
    late AppDatabase db;
    final auth = _FakeAuth();

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.createMigrator().createAll();
    });
    tearDown(() => db.close());

    test('fetches, stores a fetched rate, and toBase then uses it', () async {
      final provider = _FakeRateProvider(Decimal.parse('0.9'));
      final svc =
          DriftCurrencyService(db, auth, 'EUR', rateProvider: provider);
      final date = DateTime.utc(2026, 3, 10);

      final rate = await svc.fetchOnlineRate(
        fromCode: 'USD',
        toCode: 'EUR',
        date: date,
      );
      expect(rate, Decimal.parse('0.9'));
      expect(provider.calls, 1);

      // The stored rate is now used for conversion on that date.
      final conv = await svc.toBase(Money(Decimal.parse('10.00'), 'USD'), date);
      expect(conv.needsRate, isFalse);
      expect(conv.base!.amount, Decimal.parse('9.00')); // 10 * 0.9
    });

    test('throws when no online provider is configured', () async {
      final svc = DriftCurrencyService(db, auth, 'EUR'); // no provider
      expect(
        () => svc.fetchOnlineRate(
          fromCode: 'USD',
          toCode: 'EUR',
          date: DateTime.utc(2026, 3, 10),
        ),
        throwsA(isA<RateFetchException>()),
      );
    });
  });
}
