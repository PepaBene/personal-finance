import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/services/drift_merchant_template_service.dart';
import 'package:ledgerly_app/src/domain/enums.dart';

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
  late DriftMerchantTemplateService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
    service = DriftMerchantTemplateService(db, _FakeAuth());
  });
  tearDown(() => db.close());

  test('learnFromScan creates a normalized, keyed template', () async {
    await service.learnFromScan(
      merchant: '  Albert ',
      currencyCode: 'CZK',
      docType: DocType.receipt,
      descriptionToCategory: {'Milk 1L': 'groceries'},
    );
    final map = await service.loadByMerchantKey();
    expect(map.keys, ['albert']);
    final tpl = map['albert']!;
    expect(tpl.currencyCode, 'CZK');
    expect(tpl.docType, DocType.receipt);
    expect(tpl.categoryHints, {'milk 1l': 'groceries'});
    expect(tpl.sampleCount, 1);
  });

  test('learnFromScan merges hints and bumps the sample count', () async {
    await service.learnFromScan(
      merchant: 'Albert',
      currencyCode: 'CZK',
      descriptionToCategory: {'Milk 1L': 'groceries'},
    );
    await service.learnFromScan(
      merchant: 'Albert',
      descriptionToCategory: {'Beer 6-pack': 'alcohol'},
    );
    final tpl = (await service.loadByMerchantKey())['albert']!;
    expect(tpl.categoryHints, {
      'milk 1l': 'groceries',
      'beer 6-pack': 'alcohol',
    });
    expect(tpl.currencyCode, 'CZK'); // retained from the first scan
    expect(tpl.sampleCount, 2);
    expect(tpl.version, greaterThanOrEqualTo(2));
  });

  test('a newer scan overrides a conflicting hint', () async {
    await service.learnFromScan(
      merchant: 'Albert',
      descriptionToCategory: {'Mystery item': 'groceries'},
    );
    await service.learnFromScan(
      merchant: 'Albert',
      descriptionToCategory: {'Mystery item': 'household'},
    );
    final tpl = (await service.loadByMerchantKey())['albert']!;
    expect(tpl.categoryHints['mystery item'], 'household');
  });

  test('blank merchant is ignored', () async {
    await service.learnFromScan(merchant: '   ');
    expect(await service.loadByMerchantKey(), isEmpty);
  });
}
