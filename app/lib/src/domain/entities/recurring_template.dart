import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';
import '../money.dart';

part 'recurring_template.freezed.dart';

/// A recurring transaction template (docs/04 §4.3, FR-CAP-07). Generates draft
/// transactions on or after [nextDate]; [lastRunDate] records the most recent
/// generated occurrence so generation is idempotent across runs and devices.
@freezed
abstract class RecurringTemplateEntity with _$RecurringTemplateEntity {
  const factory RecurringTemplateEntity({
    required String id,
    required String userId,
    required TxType type,
    required String name,
    required String accountId,
    required String categoryId,
    required Money amount,
    required RecurringFrequency frequency,
    required DateTime nextDate,
    String? merchantId,
    String? note,
    DateTime? lastRunDate,
    @Default(true) bool isActive,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _RecurringTemplateEntity;

  const RecurringTemplateEntity._();

  /// The date after [from] for this cadence (weekly/monthly/yearly). Month and
  /// year steps clamp to the last valid day (e.g. Jan 31 → Feb 28).
  DateTime advance(DateTime from) {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return _addMonths(from, 1);
      case RecurringFrequency.yearly:
        return _addMonths(from, 12);
    }
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = d.day < lastDay ? d.day : lastDay;
    return DateTime.utc(year, month, day);
  }
}
