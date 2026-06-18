import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_coordinator.dart';

/// Root widget: Material 3 themed, localized (EN + CS), routed via go_router.
class LedgerlyApp extends ConsumerWidget {
  const LedgerlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the sync coordinator alive for the whole app: it owns connect /
    // disconnect / token-refresh for PowerSync (FR-SYNC-07).
    ref.watch(syncCoordinatorProvider);
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
