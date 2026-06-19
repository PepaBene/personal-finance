import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/generated/app_localizations.dart';
import 'core/preferences/preferences_controller.dart';
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
    final prefs = ref.watch(preferencesProvider);
    // High contrast bumps the Material 3 contrast level on both schemes (NFR-07).
    final contrast = prefs.highContrast ? 1.0 : 0.0;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(contrastLevel: contrast),
      darkTheme: AppTheme.dark(contrastLevel: contrast),
      themeMode: flutterThemeMode(prefs.themeMode),
      locale: prefs.localeTag == null ? null : Locale(prefs.localeTag!),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        // Honour the reduce-motion preference app-wide by folding it into
        // MediaQuery.disableAnimations, which Flutter's transitions respect
        // (NFR-07). OS-level "remove animations" still wins when set.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            disableAnimations: mq.disableAnimations || prefs.reduceMotion,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
