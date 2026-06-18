import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/sync_service.dart';
import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/router/app_router.dart';

/// Responsive Material 3 shell (docs/12 §3.1): bottom [NavigationBar] on mobile,
/// [NavigationRail] on tablet/desktop. Hosts the always-visible sync-status
/// indicator and sign-out (P12).
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _breakpoint = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final destinations = <_Dest>[
      _Dest(Routes.transactions, Icons.receipt_long_outlined, l10n.navTransactions),
      _Dest(Routes.dashboard, Icons.dashboard_outlined, l10n.navDashboard),
      _Dest(Routes.settings, Icons.settings_outlined, l10n.navSettings),
    ];
    final currentIndex = destinations
        .indexWhere((d) => GoRouterState.of(context).matchedLocation == d.path)
        .clamp(0, destinations.length - 1);

    void onSelect(int i) => context.go(destinations[i].path);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _breakpoint;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
            actions: [
              const _SyncStatus(),
              IconButton(
                tooltip: l10n.commonSignOut,
                icon: const Icon(Icons.logout),
                onPressed: () => _signOut(ref),
              ),
              SizedBox(width: context.space.xs),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      extended: constraints.maxWidth >= 1024,
                      selectedIndex: currentIndex,
                      onDestinationSelected: onSelect,
                      destinations: [
                        for (final d in destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: child),
                  ],
                )
              : child,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: onSelect,
                  destinations: [
                    for (final d in destinations)
                      NavigationDestination(icon: Icon(d.icon), label: d.label),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _signOut(WidgetRef ref) async {
    final sync = await ref.read(syncServiceProvider.future);
    await sync?.disconnect();
    ref.read(appLockServiceProvider).lock();
    ref.read(databaseKeyProvider.notifier).state = null;
    await ref.read(authServiceProvider).signOut();
  }
}

class _Dest {
  const _Dest(this.path, this.icon, this.label);
  final String path;
  final IconData icon;
  final String label;
}

class _SyncStatus extends ConsumerWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final connectivity = status?.connectivity ?? SyncConnectivity.offline;
    final (state, label) = switch (connectivity) {
      SyncConnectivity.connected => (SyncIndicatorState.synced, l10n.syncStatusSynced),
      SyncConnectivity.syncing => (SyncIndicatorState.syncing, l10n.syncStatusSyncing),
      SyncConnectivity.offline => (SyncIndicatorState.offline, l10n.syncStatusOffline),
      SyncConnectivity.error => (SyncIndicatorState.error, l10n.syncStatusError),
    };
    return SyncStatusIndicator(state: state, label: label);
  }
}
