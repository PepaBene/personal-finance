import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../money.dart';

part 'line_item.freezed.dart';

/// One purchased item / charge (docs/04 §2.2). Categorization and multi-category
/// splitting happen here. Carries sync metadata (FR-SYNC-03).
@freezed
class LineItemEntity with _$LineItemEntity {
  const factory LineItemEntity({
    required String id,
    required String userId,
    required String transactionId,
    required String description,
    required Decimal quantity,
    required Money lineAmount,
    required String categoryId,
    Money? unitPrice,
    Decimal? taxRate,
    double? ocrConfidence,
    @Default(0) int sortOrder,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _LineItemEntity;

  const LineItemEntity._();

  String get currencyCode => lineAmount.currencyCode;
}
