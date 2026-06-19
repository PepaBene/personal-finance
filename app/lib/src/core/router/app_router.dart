import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_service.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/budgets/budgets_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../application/scan_coordinator.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/lock/lock_screen.dart';
import '../../features/scan/scan_review_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/transactions/transaction_editor_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../di/providers.dart';
import 'router_refresh.dart';

/// Route paths (docs/13 §8.3). URL-addressable for web deep links.
abstract final class Routes {
  static const auth = '/auth';
  static const lock = '/lock';
  static const dashboard = '/dashboard';
  static const transactions = '/transactions';
  static const transactionNew = '/transactions/new';
  static const accounts = '/accounts';
  static const settings = '/settings';
  static const categories = '/categories';
  static const budgets = '/budgets';
  static const analytics = '/analytics';
  static const scanReview = '/scan/review';

  static String transactionEdit(String id) => '/transactions/$id/edit';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh(ref, [authStateProvider, databaseKeyProvider]);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.transactions,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider).valueOrNull;
      final unlocked = ref.read(databaseKeyProvider) != null;
      final loc = state.matchedLocation;

      // While the session is still resolving, don't bounce the user around.
      if (auth == null || auth.status == AuthStatus.unknown) return null;

      final signedIn = auth.isSignedIn;
      final atAuth = loc == Routes.auth;
      final atLock = loc == Routes.lock;

      if (!signedIn) return atAuth ? null : Routes.auth;

      // Signed in but the local DB is still locked → unlock gate.
      if (!unlocked) return atLock ? null : Routes.lock;

      // Fully authenticated and unlocked: keep them out of the gates.
      if (atAuth || atLock) return Routes.transactions;
      return null;
    },
    routes: [
      GoRoute(path: Routes.auth, builder: (_, __) => const AuthScreen()),
      GoRoute(path: Routes.lock, builder: (_, __) => const LockScreen()),
      // Full-screen editor (its own AppBar) — outside the shell chrome.
      GoRoute(
        path: Routes.transactionNew,
        builder: (_, __) => const TransactionEditorScreen(),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        builder: (_, state) =>
            TransactionEditorScreen(transactionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.categories,
        builder: (_, __) => const CategoriesScreen(),
      ),
      GoRoute(
        path: Routes.budgets,
        builder: (_, __) => const BudgetsScreen(),
      ),
      GoRoute(
        path: Routes.analytics,
        builder: (_, __) => const AnalyticsScreen(),
      ),
      // Reached from the scan flow with the captured ScanResult (draft + image
      // bytes) as `extra`. Full-screen, outside the shell chrome.
      GoRoute(
        path: Routes.scanReview,
        builder: (_, state) {
          final r = state.extra! as ScanResult;
          return ScanReviewScreen(draft: r.draft, imageBytes: r.imageBytes);
        },
      ),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.transactions,
            builder: (_, __) => const TransactionsScreen(),
          ),
          GoRoute(
            path: Routes.accounts,
            builder: (_, __) => const AccountsScreen(),
          ),
          GoRoute(
            path: Routes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
