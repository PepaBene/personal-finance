import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridges Riverpod provider changes to a [Listenable] so go_router re-evaluates
/// its redirect when auth/lock state changes. The `ref.listen` subscriptions
/// are owned by the hosting provider and closed with it; this object only needs
/// its own [ChangeNotifier] disposal (wired via `ref.onDispose`).
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref, List<ProviderListenable<Object?>> providers) {
    for (final provider in providers) {
      ref.listen<Object?>(provider, (_, __) => notifyListeners());
    }
  }
}
