import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums.dart';

part 'merchant_template.freezed.dart';

/// A learned per-merchant extraction template (docs/05 §10 footnote, FR-SCAN-10).
/// As the user confirms scans for a merchant, the app remembers that merchant's
/// typical currency, document type, and which line-item descriptions map to which
/// category — so future scans from the same merchant pre-fill more accurately.
///
/// Keyed by [merchantKey] (the normalized merchant name) so it works before a
/// merchant row exists. [categoryHints] maps a normalized line description to the
/// category the user last chose for it.
@freezed
abstract class MerchantTemplateEntity with _$MerchantTemplateEntity {
  const factory MerchantTemplateEntity({
    required String id,
    required String userId,
    required String merchantKey,
    String? currencyCode,
    DocType? docType,
    @Default(<String, String>{}) Map<String, String> categoryHints,
    @Default(0) int sampleCount,
    required DateTime updatedAt,
    @Default(false) bool deleted,
    @Default(0) int version,
  }) = _MerchantTemplateEntity;

  const MerchantTemplateEntity._();

  /// Normalized lookup key for a merchant name, or null when blank.
  static String? keyFor(String? merchant) {
    final k = normalize(merchant);
    return k.isEmpty ? null : k;
  }

  /// Normalize free text (merchant or line description) for stable matching:
  /// trimmed, lower-cased, internal whitespace collapsed.
  static String normalize(String? text) =>
      (text ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
