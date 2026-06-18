import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/currency.dart';

/// Reactive reference data for the capture/editor surfaces. Each awaits the
/// (async) service then streams from the local DB.

final categoryTreeProvider =
    StreamProvider.autoDispose<List<CategoryNode>>((ref) async* {
  final service = await ref.watch(categoryServiceProvider.future);
  yield* service.watchTree();
});

final categoriesFlatProvider =
    StreamProvider.autoDispose<List<CategoryEntity>>((ref) async* {
  final service = await ref.watch(categoryServiceProvider.future);
  yield* service.watchAll();
});

final accountsProvider =
    StreamProvider.autoDispose<List<AccountEntity>>((ref) async* {
  final service = await ref.watch(accountServiceProvider.future);
  yield* service.watchAll();
});

final accountBalancesProvider =
    StreamProvider.autoDispose<List<AccountBalance>>((ref) async* {
  final service = await ref.watch(accountServiceProvider.future);
  yield* service.watchBalances();
});

final currenciesProvider =
    StreamProvider.autoDispose<List<CurrencyEntity>>((ref) async* {
  final service = await ref.watch(currencyServiceProvider.future);
  yield* service.watchCurrencies();
});

final baseCurrencyProvider = FutureProvider.autoDispose<String>((ref) async {
  final service = await ref.watch(currencyServiceProvider.future);
  return service.baseCurrencyCode();
});
