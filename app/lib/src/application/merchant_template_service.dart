import '../domain/entities/merchant_template.dart';
import '../domain/enums.dart';

/// Stores and learns per-merchant OCR templates (FR-SCAN-10). Implemented in
/// `data/`. The scan pipeline reads a snapshot via [loadByMerchantKey]; the
/// review screen calls [learnFromScan] when a scan is confirmed.
abstract interface class MerchantTemplateService {
  /// All templates for the signed-in user, keyed by normalized merchant name —
  /// the snapshot the scan pipeline applies (docs/05 §10).
  Future<Map<String, MerchantTemplateEntity>> loadByMerchantKey();

  /// Learn from a confirmed scan: merge the merchant's typical [currencyCode]
  /// and [docType] and union [descriptionToCategory] (normalized line
  /// description → chosen category) into the merchant's template, creating it on
  /// first sight. No-op when [merchant] is blank.
  Future<void> learnFromScan({
    required String? merchant,
    String? currencyCode,
    DocType? docType,
    Map<String, String> descriptionToCategory = const {},
  });
}
