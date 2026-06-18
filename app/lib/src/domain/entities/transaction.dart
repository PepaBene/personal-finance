import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';
import '../money.dart';

part 'transaction.freezed.dart';

/// Transaction header (docs/04 §2.1). A money event; line-item detail lands in
/// Phase 1. Carries the sync metadata every synced row needs (docs/04 §1.1,
/// FR-SYNC-03): [id], [userId], [updatedAt], [deleted], [version].
///
/// `freezed` generates equality, copyWith, and immutability. Money is held as
/// the [Money] value object (never a double).
@freezed
abstract class TransactionEntity with _$TransactionEntity {
  const factory TransactionEntity({
    required String id,
    required String userId,
    required TxType type,
    required DateTime date,
    required String accountId,
    required Money total,
    required Money base,
    String? merchantId,
    String? counterAccountId,
    String? note,
    @Default(TxSource.manual) TxSource source,
    @Default(TxStatus.active) TxStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _TransactionEntity;

  const TransactionEntity._();

  bool get isActive => status == TxStatus.active && !deleted;

  /// Sign convention for aggregation/display: expenses negative, income
  /// positive, transfers neutral (excluded from income/expense aggregates).
  MoneyDirection get direction => switch (type) {
        TxType.expense => MoneyDirection.outflow,
        TxType.income => MoneyDirection.inflow,
        TxType.transfer => MoneyDirection.neutral,
      };
}

enum MoneyDirection { inflow, outflow, neutral }
