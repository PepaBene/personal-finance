import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';
import '../money.dart';

part 'account.freezed.dart';

/// Account (docs/04 §2.5).
@freezed
abstract class AccountEntity with _$AccountEntity {
  const factory AccountEntity({
    required String id,
    required String userId,
    required String name,
    required AccountKind kind,
    required String currencyCode,
    required Money openingBalance,
    @Default(false) bool isArchived,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _AccountEntity;

  const AccountEntity._();
}

/// An account with its computed current balance (opening + signed activity).
class AccountBalance {
  const AccountBalance(this.account, this.balance);
  final AccountEntity account;
  final Money balance;
}
