import '../domain/entities/account.dart';

/// Account management + balances (FR-ACC). Implemented in `data/`.
abstract interface class AccountService {
  Stream<List<AccountEntity>> watchAll();

  /// Accounts with their computed current balance (opening + signed activity),
  /// computed by SQL aggregation in the local DB (FR-ACC-02).
  Stream<List<AccountBalance>> watchBalances();

  Future<AccountEntity> upsert(AccountEntity account);

  Future<void> archive(String id);
}
