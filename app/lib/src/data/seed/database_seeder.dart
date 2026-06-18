import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums.dart';
import '../local/app_database.dart';

/// Seeds reference + default data (docs/04 §2.3, FR-CAT-01). Currencies are
/// shared reference data seeded on every device; categories, a starter account,
/// and the base-currency setting are per-user and seeded once (they then sync).
/// All inserts are idempotent.
class DatabaseSeeder {
  DatabaseSeeder(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Fixed namespace for deterministic (v5) seed ids. Deriving ids from
  /// `userId + name` makes seeding idempotent *across devices*: a second device
  /// that seeds before its first sync pull produces the same ids, so rows merge
  /// (LWW) instead of duplicating.
  static const _ns = '1b671a64-40d5-491e-99b0-da01ff1f3341';

  String _seedId(String userId, String kind, String name) =>
      _uuid.v5(_ns, '$userId:$kind:$name');

  Future<void> seed({required String userId, required String baseCurrency}) async {
    await _seedCurrencies();
    final existing = await _db.countCategories(userId);
    if (existing == 0) {
      await _seedUserDefaults(userId: userId, baseCurrency: baseCurrency);
    }
  }

  Future<void> _seedCurrencies() async {
    const seed = [
      ('CZK', 'Kč', 'Czech koruna', 2),
      ('EUR', '€', 'Euro', 2),
      ('USD', r'$', 'US dollar', 2),
      ('GBP', '£', 'Pound sterling', 2),
    ];
    for (final (code, symbol, name, digits) in seed) {
      await _db.into(_db.currencies).insertOnConflictUpdate(
            CurrenciesCompanion.insert(
              id: code,
              symbol: symbol,
              name: name,
              decimalDigits: Value(digits),
            ),
          );
    }
  }

  Future<void> _seedUserDefaults({
    required String userId,
    required String baseCurrency,
  }) async {
    final now = DateTime.now().toUtc();

    // (name, kind, parentName?, icon, colorHex)
    const roots = <(String, CategoryKind, String?, String, String)>[
      ('Food', CategoryKind.expense, null, 'restaurant', '#F28E2B'),
      ('Housing', CategoryKind.expense, null, 'home', '#4E79A7'),
      ('Transport', CategoryKind.expense, null, 'directions_car', '#76B7B2'),
      ('Health', CategoryKind.expense, null, 'health_and_safety', '#E15759'),
      ('Leisure', CategoryKind.expense, null, 'sports_esports', '#B07AA1'),
      ('Shopping', CategoryKind.expense, null, 'shopping_bag', '#FF9DA7'),
      ('Utilities', CategoryKind.expense, null, 'bolt', '#EDC948'),
      ('Fees', CategoryKind.expense, null, 'account_balance', '#9C755F'),
      ('Income', CategoryKind.income, null, 'payments', '#59A14F'),
      ('Misc', CategoryKind.expense, null, 'category', '#BAB0AC'),
    ];
    const children = <(String, CategoryKind, String, String, String)>[
      ('Groceries', CategoryKind.expense, 'Food', 'local_grocery_store', '#F28E2B'),
      ('Dining', CategoryKind.expense, 'Food', 'lunch_dining', '#FFA94D'),
      ('Rent', CategoryKind.expense, 'Housing', 'apartment', '#4E79A7'),
      ('Fuel', CategoryKind.expense, 'Transport', 'local_gas_station', '#76B7B2'),
      ('Subscriptions', CategoryKind.expense, 'Utilities', 'subscriptions', '#EDC948'),
      ('Salary', CategoryKind.income, 'Income', 'wallet', '#59A14F'),
    ];

    final idByName = <String, String>{};
    var order = 0;
    await _db.transaction(() async {
      for (final (name, kind, _, icon, color) in roots) {
        final id = _seedId(userId, 'category', name);
        idByName[name] = id;
        await _insertCategory(id, userId, name, kind, null, icon, color,
            order++, now);
      }
      for (final (name, kind, parent, icon, color) in children) {
        final id = _seedId(userId, 'category', name);
        await _insertCategory(id, userId, name, kind, idByName[parent], icon,
            color, order++, now);
      }

      // Starter account in the base currency (FR-ACC-01).
      await _db.into(_db.accounts).insertOnConflictUpdate(
            AccountsCompanion.insert(
              id: _seedId(userId, 'account', 'cash'),
              userId: userId,
              updatedAt: now,
              name: 'Cash',
              kind: AccountKind.cash,
              currencyCode: baseCurrency,
              openingBalance: Decimal.zero,
            ),
          );

      // Persist the chosen base currency (FR-CUR-01).
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(
              id: '$userId::base_currency',
              userId: userId,
              updatedAt: now,
              value: baseCurrency,
            ),
          );
    });
  }

  Future<void> _insertCategory(
    String id,
    String userId,
    String name,
    CategoryKind kind,
    String? parentId,
    String icon,
    String colorHex,
    int sortOrder,
    DateTime now,
  ) {
    return _db.into(_db.categories).insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: id,
            userId: userId,
            updatedAt: now,
            name: name,
            kind: kind,
            parentId: Value(parentId),
            icon: Value(icon),
            colorHex: Value(colorHex),
            sortOrder: Value(sortOrder),
          ),
        );
  }
}
