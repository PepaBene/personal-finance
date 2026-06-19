import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/application/auth_service.dart';
import 'package:ledgerly_app/src/data/local/app_database.dart';
import 'package:ledgerly_app/src/data/services/drift_attachment_service.dart';
import 'package:ledgerly_app/src/data/services/drift_categorization_rule_service.dart';
import 'package:ledgerly_app/src/domain/categorization/categorizer.dart';
import 'package:ledgerly_app/src/domain/categorization/category_suggestion.dart';
import 'package:ledgerly_app/src/domain/entities/attachment.dart';
import 'package:ledgerly_app/src/domain/entities/categorization_rule.dart';
import 'package:ledgerly_app/src/domain/enums.dart';

class _FakeAuth implements AuthService {
  _FakeAuth(this.userId);
  final String userId;
  @override
  AuthState get current => AuthState(
        AuthStatus.signedIn,
        AuthSession(userId: userId, email: 't@e.com'),
      );
  @override
  Stream<AuthState> watch() => Stream.value(current);
  @override
  Stream<AuthEvent> authEvents() => const Stream.empty();
  @override
  Future<void> signIn(
      {required String email, required String password}) async {}
  @override
  Future<void> signUp(
      {required String email, required String password}) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 6, 18, 12);

  CategorizationRule rule(
    String id,
    CategoryMatchType type,
    String pattern,
    String categoryId, {
    int priority = 0,
    bool enabled = true,
  }) =>
      CategorizationRule(
        id: id,
        userId: 'u1',
        matchType: type,
        pattern: pattern,
        categoryId: categoryId,
        priority: priority,
        isEnabled: enabled,
        updatedAt: now,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.createMigrator().createAll();
  });
  tearDown(() => db.close());

  group('CategorizationRuleService', () {
    late DriftCategorizationRuleService service;
    setUp(() => service = DriftCategorizationRuleService(db, _FakeAuth('u1')));

    test('upsert + watch returns rules in priority order', () async {
      await service.upsert(rule(
          'r1', CategoryMatchType.descriptionContains, 'milk', 'cat-a',
          priority: 1));
      await service.upsert(rule(
          'r2', CategoryMatchType.merchantEquals, 'Shell', 'cat-b',
          priority: 10));
      final rules = await service.watchRules().first;
      expect(rules.map((r) => r.id), ['r2', 'r1']); // priority desc
    });

    test('delete tombstones the rule so it stops appearing', () async {
      await service.upsert(
          rule('r1', CategoryMatchType.descriptionContains, 'milk', 'cat-a'));
      await service.delete('r1');
      expect(await service.watchRules().first, isEmpty);
    });

    test('buildCategorizer combines rules, merchant memory and categories',
        () async {
      // Seed a category (for keyword resolution) and a merchant default.
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat-groceries',
              userId: 'u1',
              updatedAt: now,
              name: 'Groceries',
              kind: CategoryKind.expense,
            ),
          );
      await db.into(db.merchants).insert(
            MerchantsCompanion.insert(
              id: 'm1',
              userId: 'u1',
              updatedAt: now,
              name: 'Kaufland',
              defaultCategoryId: const Value('cat-mem'),
            ),
          );
      await service.upsert(rule(
          'r1', CategoryMatchType.merchantEquals, 'Shell', 'cat-fuel-rule'));

      final categorizer = await service.buildCategorizer();

      // 1) explicit rule
      expect(
        categorizer
            .suggest(const CategorizationInput(merchant: 'Shell'))
            .source,
        CategorySource.rule,
      );
      // 2) merchant memory
      expect(
        categorizer
            .suggest(const CategorizationInput(merchant: 'Kaufland'))
            .categoryId,
        'cat-mem',
      );
      // 3) keyword dictionary resolved to the seeded category id
      expect(
        categorizer
            .suggest(const CategorizationInput(description: 'Mleko'))
            .categoryId,
        'cat-groceries',
      );
    });
  });

  group('AttachmentService', () {
    late DriftAttachmentService service;
    setUp(() => service = DriftAttachmentService(db, _FakeAuth('u1')));

    AttachmentEntity attachment(String id,
            {String? txId, DateTime? imported}) =>
        AttachmentEntity(
          id: id,
          userId: 'u1',
          transactionId: txId,
          docType: DocType.receipt,
          fileName: '$id.jpg',
          sha256: 'hash-$id',
          encNonce: 'nonce',
          scanStatus: ScanStatus.reviewed,
          importedAt: imported ?? now,
          updatedAt: now,
        );

    test('upsert + watchForTransaction returns newest first', () async {
      await service.upsert(
          attachment('a1', txId: 'tx1', imported: DateTime.utc(2026, 6, 1)));
      await service.upsert(
          attachment('a2', txId: 'tx1', imported: DateTime.utc(2026, 6, 10)));
      await service.upsert(attachment('a3', txId: 'tx2'));

      final forTx1 = await service.watchForTransaction('tx1').first;
      expect(forTx1.map((a) => a.id), ['a2', 'a1']);
      expect(forTx1.first.encNonce, 'nonce');
      expect(forTx1.first.scanStatus, ScanStatus.reviewed);
    });

    test('delete tombstones the attachment', () async {
      await service.upsert(attachment('a1', txId: 'tx1'));
      await service.delete('a1');
      expect(await service.watchForTransaction('tx1').first, isEmpty);
    });
  });
}
