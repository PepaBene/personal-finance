import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../application/auth_service.dart';
import '../../application/merchant_template_service.dart';
import '../../domain/entities/merchant_template.dart';
import '../../domain/enums.dart';
import '../local/app_database.dart' as db;

/// Drift-backed [MerchantTemplateService] (FR-SCAN-10). Templates live in the
/// local encrypted DB and sync underneath; a deterministic id keyed on
/// (user, merchantKey) keeps a merchant's template a single converging row.
class DriftMerchantTemplateService implements MerchantTemplateService {
  DriftMerchantTemplateService(this._db, this._auth);

  final db.AppDatabase _db;
  final AuthService _auth;

  static const _namespace = 'b9d7c0e2-5a1f-4c3b-9e8d-2f6a7c4b1d30';

  String get _userId {
    final session = _auth.current.session;
    if (session == null) throw StateError('No authenticated user.');
    return session.userId;
  }

  @override
  Future<Map<String, MerchantTemplateEntity>> loadByMerchantKey() async {
    final rows = await _db.getMerchantTemplates(_userId);
    return {for (final r in rows) r.merchantKey: _toEntity(r)};
  }

  @override
  Future<void> learnFromScan({
    required String? merchant,
    String? currencyCode,
    DocType? docType,
    Map<String, String> descriptionToCategory = const {},
  }) async {
    final key = MerchantTemplateEntity.keyFor(merchant);
    if (key == null) return;

    final userId = _userId;
    final existing = await _db.merchantTemplateFor(userId, key);

    // Union learned hints; the newest scan wins on a conflicting description.
    final mergedHints = <String, String>{
      if (existing != null) ...existing.categoryHints,
      for (final e in descriptionToCategory.entries)
        MerchantTemplateEntity.normalize(e.key): e.value,
    };

    final id = existing?.id ??
        const Uuid().v5(_namespace, '$userId:mtpl:$key');

    await _db.upsertMerchantTemplate(
      db.MerchantTemplatesCompanion.insert(
        id: id,
        userId: userId,
        updatedAt: DateTime.now().toUtc(),
        merchantKey: key,
        currencyCode: Value(currencyCode ?? existing?.currencyCode),
        docType: Value(docType ?? existing?.docType),
        categoryHints: Value(mergedHints),
        sampleCount: Value((existing?.sampleCount ?? 0) + 1),
        version: Value((existing?.version ?? 0) + 1),
      ),
    );
  }

  MerchantTemplateEntity _toEntity(db.MerchantTemplate r) =>
      MerchantTemplateEntity(
        id: r.id,
        userId: r.userId,
        merchantKey: r.merchantKey,
        currencyCode: r.currencyCode,
        docType: r.docType,
        categoryHints: r.categoryHints,
        sampleCount: r.sampleCount,
        updatedAt: r.updatedAt,
        deleted: r.deleted,
        version: r.version,
      );
}
