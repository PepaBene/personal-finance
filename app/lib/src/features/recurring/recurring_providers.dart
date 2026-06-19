import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/recurring_template.dart';
import '../../domain/rules/recurring_detector.dart';

/// Active recurring templates for the signed-in user.
final recurringTemplatesProvider =
    StreamProvider.autoDispose<List<RecurringTemplateEntity>>((ref) async* {
  final service = await ref.watch(recurringServiceProvider.future);
  yield* service.watchAll();
});

/// Merchant id → name, for labelling detected series and templates.
final merchantNamesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final session = ref.watch(authServiceProvider).current.session;
  if (session == null) return const {};
  return db.merchantNames(session.userId);
});

/// Heuristically-detected recurring charges from transaction history
/// (FR-ANL-08). Pure detection over the local transactions stream.
final detectedRecurringProvider =
    FutureProvider.autoDispose<List<RecurringSeries>>((ref) async {
  final txService = await ref.watch(transactionServiceProvider.future);
  final txs = await txService.watchAll().first;
  return const RecurringDetector().detect(txs);
});
