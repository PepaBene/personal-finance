import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';

part 'categorization_rule.freezed.dart';

/// A user/learned rule that maps a merchant or description pattern to a category
/// (docs/04 §4.1). Applied in [priority] order during scan parsing and as a
/// "re-apply rules" action; the first enabled match wins. Carries sync columns
/// so rules converge across the user's devices.
@freezed
abstract class CategorizationRule with _$CategorizationRule {
  const factory CategorizationRule({
    required String id,
    required String userId,
    required CategoryMatchType matchType,
    required String pattern,
    required String categoryId,
    @Default(0) int priority,
    @Default(true) bool isEnabled,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _CategorizationRule;

  const CategorizationRule._();

  /// True when this rule matches the given merchant/description. [merchant] and
  /// [description] are matched case-insensitively; an invalid [regex] never
  /// throws — it simply doesn't match.
  bool matches({String? merchant, String description = ''}) {
    if (!isEnabled) return false;
    switch (matchType) {
      case CategoryMatchType.merchantEquals:
        final m = merchant?.trim().toLowerCase();
        return m != null && m.isNotEmpty && m == pattern.trim().toLowerCase();
      case CategoryMatchType.descriptionContains:
        return description.toLowerCase().contains(pattern.toLowerCase());
      case CategoryMatchType.regex:
        try {
          return RegExp(pattern, caseSensitive: false).hasMatch(description);
        } on FormatException {
          return false;
        }
    }
  }
}
